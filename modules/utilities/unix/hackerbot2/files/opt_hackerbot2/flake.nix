{
  description = "Hackerbot - AI-Powered Cybersecurity Training Framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Development shell
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Ruby and development tools
            ruby_3_3
            bundix

            # IRC server and client
            python3
            weechat

            # System utilities
            curl
            wget
            git
            vim
            tree
            htop
          ];

          # Environment variables
          RUBYOPT = "-KU -E utf-8:utf-8";
          IRCD_PORT = "6667";
          IRCD_HOST = "localhost";
          GEM_HOME = "./.gems";
          GEM_PATH = "./.gems";

          shellHook = ''
            echo "🤖 Hackerbot Development Environment"
            echo "===================================="
            echo "Ruby: $(ruby --version)"
            echo "Nix: $(nix --version | head -n1)"
            echo ""
            echo "Available commands:"
            echo "  start-irc           - Start IRC server"
            echo "  stop-irc            - Stop IRC server"
            echo "  start-irc-server    - Start IRC server (alias)"
            echo "  stop-irc-server     - Stop IRC server (alias)"
            echo "  connect-irc         - Connect with WeeChat"
            echo "  make bot            - Start the bot"
            echo "  install-gems        - Install required Ruby gems"
            echo ""
            echo "Quick start:"
            echo "  1. make start-irc"
            echo "  2. make connect-irc (in another terminal)"
            echo "  3. make bot (in another terminal)"
            echo ""
            echo "IRC server running on localhost:6667"
            echo ""

            # Create local gem directory
            mkdir -p .gems

            # Add local gem bin to PATH
            export PATH="$(pwd)/.gems/bin:$PATH"
            export GEM_HOME="$(pwd)/.gems"
            export GEM_PATH="$(pwd)/.gems"

            # Create IRC server configuration if it doesn't exist
            if [ ! -f "ircd.conf" ]; then
              echo "Creating default IRC server configuration..."
              cat > ircd.conf << 'EOF'
<config format="xml">
    <server name="irc.hackerbot.local"
            description="Hackerbot Development IRC Server"
            network="HackerNet">

    <admin name="Hackerbot Admin"
           nick="admin"
           email="admin@hackerbot.local">

    <bind address="127.0.0.1" port="6667" type="clients">

    <connect name="main"
             allow="*"
             maxchans="20"
             sendq="131074"
             recvq="8192">

    <channel name="#hackerbot" modes="t">

    <module name="m_helpop.so">

    <oper name="admin"
          password="admin123"
          host="*@127.0.0.1"
          type="NetAdmin">

    <type name="NetAdmin" classes="HostCloak OperChat BanControl">
    <class name="HostCloak" commands="SETHOST SETIDENT SETNAME CHGHOST CHGIDENT">
    <class name="OperChat" commands="SAJOIN SAPART SANICK SAQUIT SATOPIC KILL">
    <class name="BanControl" commands="KICK GLINE KLINE ZLINE QLINE ELINE">

    <pid file="/tmp/ircd.pid">
    <options prefixquit="Quit: " defaultmodes="+ixw">
</config>
EOF
            fi

            # Create convenience aliases
            alias start-irc-server="echo 'Starting IRC server...' && nohup python3 simple_irc_server.py > /tmp/ircd.log 2>&1 & echo \$! > /tmp/ircd.pid && sleep 1 && if kill -0 \$(cat /tmp/ircd.pid 2>/dev/null) 2>/dev/null; then echo 'IRC server started on localhost:6667 (PID: '\$(cat /tmp/ircd.pid)')'; else echo 'Failed to start IRC server'; rm -f /tmp/ircd.pid; fi"
            alias stop-irc-server="if [ -f /tmp/ircd.pid ]; then if kill -0 \$(cat /tmp/ircd.pid 2>/dev/null) 2>/dev/null; then kill \$(cat /tmp/ircd.pid) && rm -f /tmp/ircd.pid && echo 'IRC server stopped'; else echo 'IRC server not running (stale PID file removed)'; rm -f /tmp/ircd.pid; fi; else echo 'IRC server not running'; fi"
            alias connect-irc="echo 'Use WeeChat to connect: /server add localhost localhost/6667; /connect localhost; /join #hackerbot' && weechat"
            alias install-gems="gem install --user-install --install-dir \"$GEM_HOME\" --bindir \"$GEM_HOME/bin\" ircinch nokogiri nori json httparty thwait kramdown"

            # Check if gems are installed and install if needed
            if ! gem list ircinch > /dev/null 2>&1; then
              echo "Installing Ruby dependencies..."
              gem install --user-install --install-dir "$GEM_HOME" --bindir "$GEM_HOME/bin" ircinch nokogiri nori json httparty thwait kramdown
              echo "Gems installed successfully!"
            else
              echo "Ruby dependencies already installed."
            fi

            echo ""
            echo "Environment ready! Ruby and IRC tools are available."
            echo "Gems are installed in: $(pwd)/.gems"
          '';
        };
      in
      {
        devShells.default = devShell;

        apps = {
          start-irc-server = {
            type = "app";
            program = "${pkgs.writeShellScript "start-irc-server" ''
              set -e
              if [ ! -f "ircd.conf" ]; then
                echo "Creating IRC server configuration..."
                cat > ircd.conf << 'EOF'
<config format="xml">
  <server name="irc.hackerbot.local"
          description="Hackerbot Development IRC Server"
          network="HackerNet">
  <admin name="Hackerbot Admin" nick="admin" email="admin@hackerbot.local">
  <bind address="127.0.0.1" port="6667" type="clients">
  <connect name="main" allow="*" maxchans="20" sendq="131074" recvq="8192">
  <channel name="#hackerbot" modes="t">
  <module name="m_helpop.so">
  <oper name="admin" password="admin123" host="*@127.0.0.1" type="NetAdmin">
  <type name="NetAdmin" classes="HostCloak OperChat BanControl">
  <class name="HostCloak" commands="SETHOST SETIDENT SETNAME CHGHOST CHGIDENT">
  <class name="OperChat" commands="SAJOIN SAPART SANICK SAQUIT SATOPIC KILL">
  <class name="BanControl" commands="KICK GLINE KLINE ZLINE QLINE ELINE">
  <pid file="/tmp/ircd.pid">
  <options prefixquit="Quit: " defaultmodes="+ixw">
</config>
EOF
              fi

              # Check if server is already running
              if [ -f /tmp/ircd.pid ]; then
                if kill -0 $(cat /tmp/ircd.pid) 2>/dev/null; then
                  echo "IRC server is already running (PID: $(cat /tmp/ircd.pid))"
                  exit 0
                else
                  echo "Removing stale PID file..."
                  rm -f /tmp/ircd.pid
                fi
              fi

              # Start the server in background with proper daemonization
              nohup ${pkgs.python3}/bin/python3 simple_irc_server.py > /tmp/ircd.log 2>&1 &
              SERVER_PID=$!

              # Wait a moment to check if server started successfully
              sleep 2

              # Check if the process is still running
              if kill -0 $SERVER_PID 2>/dev/null; then
                echo $SERVER_PID > /tmp/ircd.pid
                echo "IRC server started successfully on localhost:6667 (PID: $SERVER_PID)"
                echo "Use 'make connect-irc' to connect with WeeChat"
                echo "Log file: /tmp/ircd.log"
              else
                echo "Failed to start IRC server. Check /tmp/ircd.log for details."
                exit 1
              fi
            ''}";
          };

          stop-irc-server = {
            type = "app";
            program = "${pkgs.writeShellScript "stop-irc-server" ''
              if [ -f /tmp/ircd.pid ]; then
                kill $(cat /tmp/ircd.pid) 2>/dev/null || true
                rm -f /tmp/ircd.pid
                echo "IRC server stopped"
              else
                echo "IRC server not running"
              fi
            ''}";
          };
        };
      });
}
