"""
Gunicorn WSGI entrypoint with /healthz endpoint.

Imports the Flask app from the voting-app source and registers
a dedicated /healthz route for Kubernetes probes.
This keeps liveness/readiness checks separate from application traffic.
"""
from app import app
import flask


@app.route("/healthz")
def healthz():
    """Simple health check — returns OK if the app is running."""
    return flask.jsonify({"status": "ok"})


# Alias for gunicorn (wsgi:application)
application = app


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True, threaded=True)
