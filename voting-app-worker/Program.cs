using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Npgsql;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using RabbitMQ.Client.Exceptions;

namespace Worker
{
    public class Program
    {
        public static int Main(string[] args)
        {
            try
            {
                var dbHost = Environment.GetEnvironmentVariable("POSTGRES_HOST") ?? "db";
                var dbUser = Environment.GetEnvironmentVariable("POSTGRES_USER") ?? "postgres";
                var dbPass = Environment.GetEnvironmentVariable("POSTGRES_PASSWORD") ?? "postgres";
                var dbName = Environment.GetEnvironmentVariable("POSTGRES_DB") ?? "postgres";
                var connStr = $"Server={dbHost};Username={dbUser};Password={dbPass};Database={dbName};";

                var rabbitHost = Environment.GetEnvironmentVariable("RABBITMQ_HOST") ?? "rabbitmq";
                var rabbitPort = int.Parse(Environment.GetEnvironmentVariable("RABBITMQ_PORT") ?? "5672");
                var rabbitUser = Environment.GetEnvironmentVariable("RABBITMQ_USER") ?? "voting-app";
                var rabbitPass = Environment.GetEnvironmentVariable("RABBITMQ_PASS") ?? "CHANGEME_rabbitmq";

                // Open DB connection
                var pgsql = OpenDbConnection(connStr);
                var keepAliveCommand = pgsql.CreateCommand();
                keepAliveCommand.CommandText = "SELECT 1";

                var definition = new { vote = "", voter_id = "" };

                // ─── RabbitMQ Connection ──────────────────────────────────
                var factory = new ConnectionFactory
                {
                    HostName = rabbitHost,
                    Port = rabbitPort,
                    UserName = rabbitUser,
                    Password = rabbitPass,
                    VirtualHost = "/",
                    DispatchConsumersAsync = true,
                    AutomaticRecoveryEnabled = true,
                    NetworkRecoveryInterval = TimeSpan.FromSeconds(10),
                    TopologyRecoveryEnabled = true,
                    RequestedHeartbeat = TimeSpan.FromSeconds(30),
                };

                Console.WriteLine($"Connecting to RabbitMQ at {rabbitHost}:{rabbitPort}...");
                var connection = factory.CreateConnection();
                var channel = connection.CreateModel();

                // Declare the same stream queue that vote-app publishes to
                channel.QueueDeclare(
                    queue: "votes",
                    durable: true,
                    exclusive: false,
                    autoDelete: false,
                    arguments: new Dictionary<string, object>
                    {
                        { "x-queue-type", "stream" },
                        { "x-max-length-bytes", 10_000_000_000 },
                        { "x-max-age", "24h" },
                    }
                );

                // Only 1 unacked message at a time — back-pressure
                channel.BasicQos(0, 1, false);

                Console.WriteLine("RabbitMQ connected. Starting consumer...");

                var consumer = new AsyncEventingBasicConsumer(channel);
                consumer.Received += async (model, ea) =>
                {
                    try
                    {
                        var body = ea.Body.ToArray();
                        var json = Encoding.UTF8.GetString(body);
                        var vote = JsonConvert.DeserializeAnonymousType(json, definition);

                        if (vote == null)
                        {
                            Console.Error.WriteLine("Skipping null vote message");
                            channel.BasicAck(ea.DeliveryTag, false);
                            return;
                        }

                        Console.WriteLine($"Processing vote for '{vote.vote}' by '{vote.voter_id}'");

                        // Reconnect DB if down
                        if (!pgsql.State.Equals(System.Data.ConnectionState.Open))
                        {
                            Console.WriteLine("Reconnecting DB");
                            pgsql = OpenDbConnection(connStr);
                        }

                        UpdateVote(pgsql, vote.voter_id, vote.vote);
                        channel.BasicAck(ea.DeliveryTag, false);
                        Console.WriteLine($"Vote ack'd: {vote.vote}");
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine($"Error processing message: {ex.Message}");
                        // Nack without requeue to avoid poison-message loop
                        // Stream queues retain the message anyway
                        try
                        {
                            channel.BasicNack(ea.DeliveryTag, false, false);
                        }
                        catch
                        {
                            // Channel may be closed during recovery
                        }
                    }
                };

                // For stream queues: "last" means start consuming new messages only
                channel.BasicConsume(
                    queue: "votes",
                    autoAck: false,
                    consumerTag: "worker",
                    noLocal: false,
                    exclusive: false,
                    arguments: new Dictionary<string, object>
                    {
                        { "x-stream-offset", "last" },
                    },
                    consumer: consumer
                );

                Console.WriteLine("Worker started, waiting for messages from RabbitMQ...");
                Console.WriteLine("Press Ctrl+C to stop.");

                // Block main thread forever (event-driven)
                var exitEvent = new ManualResetEventSlim(false);
                Console.CancelKeyPress += (sender, e) =>
                {
                    e.Cancel = true;
                    Console.WriteLine("Shutting down...");
                    exitEvent.Set();
                };

                // Keep DB alive while waiting for messages
                while (!exitEvent.IsSet(0))
                {
                    if (pgsql.State.Equals(System.Data.ConnectionState.Open))
                    {
                        keepAliveCommand.ExecuteNonQuery();
                    }
                    exitEvent.Wait(TimeSpan.FromSeconds(30));
                }

                Console.WriteLine("Cleaning up...");
                channel.Close();
                connection.Close();
                pgsql.Close();
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 1;
            }
        }

        private static NpgsqlConnection OpenDbConnection(string connectionString)
        {
            NpgsqlConnection connection;

            while (true)
            {
                try
                {
                    connection = new NpgsqlConnection(connectionString);
                    connection.Open();
                    break;
                }
                catch (SocketException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
                catch (DbException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
            }

            Console.Error.WriteLine("Connected to db");

            var command = connection.CreateCommand();
            command.CommandText = @"CREATE TABLE IF NOT EXISTS votes (
                                        id VARCHAR(255) NOT NULL UNIQUE,
                                        vote VARCHAR(255) NOT NULL
                                    )";
            command.ExecuteNonQuery();

            return connection;
        }

        private static void UpdateVote(NpgsqlConnection connection, string voterId, string vote)
        {
            var command = connection.CreateCommand();
            try
            {
                command.CommandText = "INSERT INTO votes (id, vote) VALUES (@id, @vote)";
                command.Parameters.AddWithValue("@id", voterId);
                command.Parameters.AddWithValue("@vote", vote);
                command.ExecuteNonQuery();
            }
            catch (DbException)
            {
                command.CommandText = "UPDATE votes SET vote = @vote WHERE id = @id";
                command.ExecuteNonQuery();
            }
            finally
            {
                command.Dispose();
            }
        }
    }
}
