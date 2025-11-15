#!/usr/bin/env python3
"""
Test script to verify case-insensitive channel handling in the IRC server.
This script demonstrates that channels with capital letters work correctly.
"""

import socket
import threading
import time
import sys
import os

# Add parent directory to path to import the server
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def send_command(sock, command):
    """Send an IRC command to the server."""
    try:
        sock.send(f"{command}\r\n".encode())
    except:
        pass

def receive_messages(sock, timeout=1):
    """Receive messages from the server with timeout."""
    sock.settimeout(timeout)
    messages = []
    try:
        while True:
            data = sock.recv(1024).decode()
            if not data:
                break
            for line in data.split('\r\n'):
                if line.strip():
                    messages.append(line.strip())
    except socket.timeout:
        pass
    return messages

def test_case_insensitive_channels():
    """Test that channels work case-insensitively."""

    print("Testing case-insensitive channel handling...")

    # Connect to server
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect(('127.0.0.1', 6667))
    except:
        print("❌ Could not connect to IRC server. Make sure it's running on port 6667")
        return False

    # Register client
    send_command(sock, "NICK TestUser")
    send_command(sock, "USER testuser 0 * :Test User")

    # Wait for registration
    time.sleep(0.5)
    receive_messages(sock)

    # Test 1: Join channel with capital letters
    print("\n1. Joining channel #TestChannel (with capitals)...")
    send_command(sock, "JOIN #TestChannel")
    time.sleep(0.5)
    messages = receive_messages(sock)

    join_success = any(":TestUser!~user@localhost JOIN #TestChannel" in msg for msg in messages)
    if join_success:
        print("✓ Successfully joined #TestChannel")
    else:
        print("❌ Failed to join #TestChannel")
        print(f"Received messages: {messages}")
        return False

    # Test 2: Send message to channel using lowercase
    print("\n2. Sending message to #testchannel (lowercase)...")
    send_command(sock, "PRIVMSG #testchannel :Hello from test!")
    time.sleep(0.5)
    messages = receive_messages(sock)

    # Should receive our own message back
    message_sent = any("Hello from test!" in msg for msg in messages)
    if message_sent:
        print("✓ Message sent successfully to #testchannel")
    else:
        print("❌ Failed to send message to #testchannel")
        print(f"Received messages: {messages}")
        return False

    # Test 3: Join same channel with different case
    print("\n3. Joining #TESTCHANNEL (all uppercase)...")
    send_command(sock, "JOIN #TESTCHANNEL")
    time.sleep(0.5)
    messages = receive_messages(sock)

    # Should not receive another JOIN message since we're already in the channel
    no_duplicate_join = not any(":TestUser!~user@localhost JOIN #TESTCHANNEL" in msg for msg in messages)
    if no_duplicate_join:
        print("✓ Correctly recognized we're already in the channel")
    else:
        print("❌ Server treated #TESTCHANNEL as a different channel")
        return False

    # Test 4: LIST command should show channel with original case
    print("\n4. Testing LIST command...")
    send_command(sock, "LIST")
    time.sleep(0.5)
    messages = receive_messages(sock)

    list_has_canonical = any("#TestChannel" in msg for msg in messages)
    if list_has_canonical:
        print("✓ LIST command shows channel with correct case (#TestChannel)")
    else:
        print("❌ LIST command doesn't show correct case")
        print(f"Received messages: {messages}")
        return False

    # Test 5: NAMES command with different case
    print("\n5. Testing NAMES command with different case...")
    send_command(sock, "NAMES #testchannel")
    time.sleep(0.5)
    messages = receive_messages(sock)

    names_success = any("#TestChannel" in msg and "TestUser" in msg for msg in messages)
    if names_success:
        print("✓ NAMES command works case-insensitively")
    else:
        print("❌ NAMES command failed with case mismatch")
        print(f"Received messages: {messages}")
        return False

    # Test 6: PART command with different case
    print("\n6. Testing PART command with different case...")
    send_command(sock, "PART #testchannel")
    time.sleep(0.5)
    messages = receive_messages(sock)

    part_success = any(":TestUser!~user@localhost PART #TestChannel" in msg for msg in messages)
    if part_success:
        print("✓ PART command works case-insensitively")
    else:
        print("❌ PART command failed with case mismatch")
        print(f"Received messages: {messages}")
        return False

    sock.close()
    return True

def main():
    """Run the test."""
    print("IRC Server Case-Insensitive Channel Test")
    print("=" * 50)

    try:
        success = test_case_insensitive_channels()
        if success:
            print("\n" + "=" * 50)
            print("🎉 All tests passed! Case-insensitive channel handling works correctly.")
            print("\nThe IRC server now properly handles channels with capital letters:")
            print("- Channels are created with the original case preserved")
            print("- All operations work case-insensitively")
            print("- JOIN, PRIVMSG, LIST, NAMES, and PART commands all work correctly")
        else:
            print("\n" + "=" * 50)
            print("❌ Some tests failed. Please check the server implementation.")
            return 1
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())
