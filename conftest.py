import pytest

def pytest_addoption(parser):
    parser.addoption("--database", action="store", default="default")
