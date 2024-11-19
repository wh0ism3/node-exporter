#!/bin/bash

# Define variables
NODE_EXPORTER_VERSION="1.6.1"
NODE_EXPORTER_USER="node_exporter"

# Update the system
echo "Updating system packages..."
yum -y update

# Download Node Exporter
echo "Downloading Node Exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz

# Extract the archive
echo "Extracting Node Exporter..."
tar -xzf /tmp/node_exporter.tar.gz -C /tmp
mv /tmp/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64 /usr/local/bin/node_exporter

# Create a dedicated user
echo "Creating Node Exporter user..."
useradd -rs /bin/false $NODE_EXPORTER_USER

# Set permissions
echo "Setting permissions..."
chown -R $NODE_EXPORTER_USER:$NODE_EXPORTER_USER /usr/local/bin/node_exporter

# Create a systemd service file (if using CentOS 7 or higher)
# Otherwise, use init.d script for CentOS 6
if [ -d /usr/lib/systemd/system ]; then
    echo "Setting up systemd service..."
    cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_EXPORTER_USER
ExecStart=/usr/local/bin/node_exporter/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
else
    # Create init.d script for CentOS 6
    echo "Creating init.d script..."
    cat <<EOF > /etc/init.d/node_exporter
#!/bin/bash
#
# Node Exporter
#
# chkconfig: 345 99 10
# description: Prometheus Node Exporter

. /etc/init.d/functions

USER=$NODE_EXPORTER_USER
EXEC=/usr/local/bin/node_exporter/node_exporter
PIDFILE=/var/run/node_exporter.pid
LOGFILE=/var/log/node_exporter.log

start() {
    echo -n "Starting Node Exporter: "
    daemon --user=$USER --pidfile=\$PIDFILE \$EXEC >>\$LOGFILE 2>&1 &
    RETVAL=\$?
    echo
    [ \$RETVAL -eq 0 ] && touch /var/lock/subsys/node_exporter
    return \$RETVAL
}

stop() {
    echo -n "Stopping Node Exporter: "
    killproc -p \$PIDFILE \$EXEC
    RETVAL=\$?
    echo
    [ \$RETVAL -eq 0 ] && rm -f /var/lock/subsys/node_exporter
    return \$RETVAL
}

case "\$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status -p \$PIDFILE \$EXEC
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|restart}"
        exit 1
esac

exit 0
EOF

    chmod +x /etc/init.d/node_exporter
    chkconfig --add node_exporter
    service node_exporter start
fi

echo "Node Exporter installation completed successfully."
