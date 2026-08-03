import os
import sys

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app import app as flask_app  # noqa: E402


@pytest.fixture
def client():
    flask_app.config.update(TESTING=True)
    with flask_app.test_client() as test_client:
        yield test_client
