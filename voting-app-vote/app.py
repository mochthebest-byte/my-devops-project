from flask import Flask, render_template, request, make_response, g
import pika
import os
import socket
import random
import json
import logging

option_a = os.getenv('OPTION_A', "Cats")
option_b = os.getenv('OPTION_B', "Dogs")
hostname = socket.gethostname()

RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'rabbitmq')
RABBITMQ_PORT = int(os.getenv('RABBITMQ_PORT', '5672'))

app = Flask(__name__)

gunicorn_error_logger = logging.getLogger('gunicorn.error')
app.logger.handlers.extend(gunicorn_error_logger.handlers)
app.logger.setLevel(logging.INFO)

# Global RabbitMQ connection (lazy, per-process — gunicorn pre-fork model)
_rabbitmq_conn = None
_rabbitmq_channel = None

def get_rabbitmq():
    global _rabbitmq_conn, _rabbitmq_channel
    if _rabbitmq_conn is None or _rabbitmq_conn.is_closed:
        app.logger.info("Connecting to RabbitMQ at %s:%d", RABBITMQ_HOST, RABBITMQ_PORT)
        credentials = pika.PlainCredentials(
            os.getenv('RABBITMQ_USER', 'voting-app'),
            os.getenv('RABBITMQ_PASS', 'CHANGEME_rabbitmq'),
        )
        params = pika.ConnectionParameters(
            host=RABBITMQ_HOST,
            port=RABBITMQ_PORT,
            credentials=credentials,
            heartbeat=30,
            blocked_connection_timeout=300,
        )
        _rabbitmq_conn = pika.BlockingConnection(params)
        _rabbitmq_channel = _rabbitmq_conn.channel()
        # Declare a stream queue for votes — durable, persistent, non-destructive
        _rabbitmq_channel.queue_declare(
            queue='votes',
            durable=True,
            arguments={
                'x-queue-type': 'stream',
                'x-max-length-bytes': 10_000_000_000,
                'x-max-age': '24h',
            },
        )
        app.logger.info("RabbitMQ connected, queue 'votes' ready")
    return _rabbitmq_channel


@app.route("/", methods=['POST', 'GET'])
def hello():
    voter_id = request.cookies.get('voter_id')
    if not voter_id:
        voter_id = hex(random.getrandbits(64))[2:-1]

    vote = None

    if request.method == 'POST':
        vote = request.form['vote']
        app.logger.info('Received vote for %s', vote)
        data = json.dumps({'voter_id': voter_id, 'vote': vote})

        try:
            channel = get_rabbitmq()
            channel.basic_publish(
                exchange='',
                routing_key='votes',
                body=data,
                properties=pika.BasicProperties(
                    delivery_mode=2,  # persistent
                ),
            )
            app.logger.info('Vote published to RabbitMQ: %s', data)
        except Exception as e:
            app.logger.error('Failed to publish vote to RabbitMQ: %s', e)
            # Reset connection on error so next request reconnects
            global _rabbitmq_conn, _rabbitmq_channel
            _rabbitmq_conn = None
            _rabbitmq_channel = None

    resp = make_response(render_template(
        'index.html',
        option_a=option_a,
        option_b=option_b,
        hostname=hostname,
        vote=vote,
    ))
    resp.set_cookie('voter_id', voter_id)
    return resp


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80, debug=True, threaded=True)
