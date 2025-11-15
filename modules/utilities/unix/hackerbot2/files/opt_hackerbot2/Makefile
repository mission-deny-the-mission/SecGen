# Makefile for Hackerbot Development

.PHONY: help dev setup start-irc stop-irc test clean build install

# Default target
help:
	@echo "Hackerbot Development Commands"
	@echo "============================="
	@echo ""
	@echo "Setup Commands:"
	@echo "  dev          - Enter Nix development environment"
	@echo "  setup        - Initial project setup"
	@echo ""
	@echo "IRC Server:"
	@echo "  start-irc    - Start IRC server"
	@echo "  stop-irc     - Stop IRC server"
	@echo "  restart-irc  - Restart IRC server"
	@echo ""
	@echo "Bot Commands:"
	@echo "  bot          - Start Hackerbot with defaults"
	@echo "  bot-ollama   - Start Hackerbot with Ollama"
	@echo "  bot-rag-cag  - Start Hackerbot with RAG + CAG"
	@echo ""
	@echo "Development:"
	@echo "  test         - Run test suite"
	@echo "  clean        - Clean temporary files"
	@echo "  install-gems - Install required Ruby gems"
	@echo ""
	@echo "Nix Commands:"
	@echo "  build        - Build the package"
	@echo "  install      - Install to profile"
	@echo ""

# Development environment
dev:
	nix develop

# Initial setup
setup:
	@echo "Setting up Hackerbot development environment..."
	nix develop --command bash -c " \
		if [ ! -f '.gems/bin/ircinch' ]; then \
			echo 'Installing Ruby dependencies...'; \
			gem install --user-install --install-dir $(pwd)/.gems --bindir $(pwd)/.gems/bin ircinch nokogiri nori json httparty; \
		fi; \
		echo 'Setup complete!' \
	"

# IRC server management - use simple approach
start-irc:
	@echo "Starting IRC server..."
	@if [ -f /tmp/ircd.pid ]; then \
		if kill -0 $$(cat /tmp/ircd.pid) 2>/dev/null; then \
			echo "IRC server is already running (PID: $$(cat /tmp/ircd.pid))"; \
			exit 0; \
		else \
			echo "Removing stale PID file..."; \
			rm -f /tmp/ircd.pid; \
		fi; \
	fi
	@echo "Starting IRC server..."
	@nohup python3 simple_irc_server.py > /tmp/ircd.log 2>&1 & echo $$! > /tmp/ircd.pid
	@sleep 2
	@if kill -0 $$(cat /tmp/ircd.pid) 2>/dev/null; then \
		echo "IRC server started successfully on localhost:6667 (PID: $$(cat /tmp/ircd.pid))"; \
		echo "Use 'make connect-irc' to connect with WeeChat"; \
		echo "Log file: /tmp/ircd.log"; \
	else \
		echo "Failed to start IRC server. Check /tmp/ircd.log for details."; \
		rm -f /tmp/ircd.pid; \
	fi

stop-irc:
	@echo "Stopping IRC server..."
	@if [ -f /tmp/ircd.pid ]; then \
		if kill -0 $$(cat /tmp/ircd.pid) 2>/dev/null; then \
			kill $$(cat /tmp/ircd.pid); \
			rm -f /tmp/ircd.pid; \
			echo "IRC server stopped"; \
		else \
			echo "IRC server not running (stale PID file removed)"; \
			rm -f /tmp/ircd.pid; \
		fi; \
	else \
		echo "IRC server not running"; \
	fi

restart-irc: stop-irc start-irc

# Bot commands
bot:
	@echo "Starting Hackerbot with default settings..."
	nix develop --command ruby hackerbot.rb --irc-server localhost

bot-ollama:
	@echo "Starting Hackerbot with Ollama..."
	nix develop --command ruby hackerbot.rb \
		--irc-server localhost \
		--llm-provider ollama \
		--ollama-model gemma3:1b

bot-rag-cag:
	@echo "Starting Hackerbot with RAG + CAG..."
	nix develop --command ruby hackerbot.rb \
		--irc-server localhost \
		--enable-rag-cag \
		--llm-provider ollama \
		--ollama-model gemma3:1b

bot-rag-only:
	@echo "Starting Hackerbot with RAG only (recommended for testing)..."
	nix develop --command ruby hackerbot.rb \
		--irc-server localhost \
		--enable-rag-cag \
		--rag-only \
		--llm-provider ollama \
		--ollama-model gemma3:1b

# Development commands
test:
	nix develop --command ruby test_all.rb

lint:
	nix develop --command ruby -c \
		hackerbot.rb bot_manager.rb rag_cag_manager.rb print.rb || echo "Syntax check complete"

clean:
	@echo "Cleaning temporary files..."
	rm -f ircd.pid
	rm -f *.log
	rm -rf .bundle/
	rm -f Gemfile.lock
	rm -rf vendor/
	rm -rf .gems/

# Nix commands
build:
	nix build

install:
	nix profile install .#hackerbot

# Quick start
quick-start: setup start-irc
	@echo ""
	@echo "Quick start complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Open a new terminal and run: make connect-irc"
	@echo "2. In another terminal, run: make bot"
	@echo ""

# Connect to IRC
connect-irc:
	@echo "Starting IRC client..."
	nix develop --command bash -c " \
		echo 'IRC Client Instructions:'; \
		echo '1. Connect to localhost:6667'; \
		echo '2. Channel: #hackerbot'; \
		echo '3. Nickname: your-choice'; \
		echo ''; \
		echo 'Example with irssi:'; \
		echo 'irssi -c localhost -p 6667 -n yournick'; \
		echo '/join #hackerbot'; \
		echo ''; \
		echo 'Example with WeeChat:'; \
		echo 'weechat'; \
		echo '/server add localhost localhost/6667'; \
		echo '/connect localhost'; \
		echo '/join #hackerbot'; \
		echo ''; \
		echo 'Starting WeeChat...'; \
		weechat \
	"

# Development demo
demo:
	@echo "Running Hackerbot demo..."
	nix develop --command ruby demo_rag_cag.rb

# Check environment
env:
	nix develop --command bash -c " \
		echo 'Environment check:'; \
		echo 'Ruby: '$$(ruby --version); \
		echo 'InspIRCd: '$$(which inspircd); \
		echo 'GEM_HOME: '$$GEM_HOME; \
		echo 'GEM_PATH: '$$GEM_PATH; \
		echo ''; \
		echo 'Gems installed:'; \
		gem list 2>/dev/null | grep -E '(ircinch|nokogiri|nori|json|httparty)' || echo 'Some gems may not be installed' \
	"

# Install gems manually (bundler alternative)
install-gems:
	@echo "Installing gems locally..."
	nix develop --command bash -c " \
		mkdir -p .gems/bin; \
		gem install --user-install --install-dir $(pwd)/.gems --bindir $(pwd)/.gems/bin ircinch nokogiri nori json httparty; \
		echo 'Gems installed in $(pwd)/.gems/' \
	"

# Full development setup (includes IRC server)
dev-setup: env setup start-irc
	@echo ""
	@echo "Development environment ready!"
	@echo "IRC server running on localhost:6667"
	@echo "Use 'make connect-irc' to test connection"
	@echo "Use 'make bot' to start Hackerbot"
	@echo ""

# Check if IRC server is running
status:
	@echo "Checking IRC server status..."
	@if [ -f /tmp/ircd.pid ]; then \
		if kill -0 $$(cat /tmp/ircd.pid) 2>/dev/null; then \
			echo "IRC server is running (PID: $$(cat /tmp/ircd.pid))"; \
		else \
			echo "IRC server PID file exists but process is not running"; \
		fi; \
	else \
		echo "IRC server is not running"; \
	fi

# Verify all components are working
verify: clean setup env
	@echo ""
	@echo "Verification complete!"
	@echo "All components are ready for development."
	@echo ""
	@echo "To start development:"
	@echo "1. make start-irc"
	@echo "2. make connect-irc (in new terminal)"
	@echo "3. make bot (in new terminal)"
