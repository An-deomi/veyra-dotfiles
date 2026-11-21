#!/usr/bin/env python3
"""Authenticate the current user using a password supplied only over stdin."""

import sys

sys.dont_write_bytecode = True

import getpass

try:
    import pam
except ImportError:
    print("Error: python-pam is not installed. Please install it.", file=sys.stderr)
    sys.exit(1)


def authenticate(password: str) -> bool:
    if not password:
        return False
    return bool(pam.pam().authenticate(getpass.getuser(), password))


if __name__ == "__main__":
    if len(sys.argv) != 1:
        print("Error: password input must be provided through stdin.", file=sys.stderr)
        sys.exit(2)

    password = sys.stdin.readline().rstrip("\r\n")
    sys.exit(0 if authenticate(password) else 1)
