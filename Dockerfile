# syntax=docker/dockerfile:1.4
FROM --platform=linux/amd64 ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root

# Desktop, VNC, noVNC and basic tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        xfce4 xfce4-goodies \
        tigervnc-standalone-server tigervnc-common \
        novnc websockify \
        dbus-x11 x11-utils x11-xserver-utils x11-apps \
        xterm sudo vim net-tools curl wget git tzdata \
        openssl ca-certificates gnupg xubuntu-icon-theme \
    && ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html \
    && rm -rf /var/lib/apt/lists/*

# Firefox as a real .deb from Mozilla's official APT repo
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
         -o /etc/apt/keyrings/packages.mozilla.org.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
         > /etc/apt/sources.list.d/mozilla.list \
    && printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1001\n' \
         > /etc/apt/preferences.d/mozilla-firefox \
    && echo 'Unattended-Upgrade::Allowed-Origins:: "packages.mozilla.org:mozilla";' \
         > /etc/apt/apt.conf.d/51unattended-upgrades-firefox \
    && apt-get update \
    && apt-get install -y firefox \
    && rm -rf /var/lib/apt/lists/*

# VNC session startup, in the NEW TigerVNC config location
COPY <<'EOF' /root/.config/tigervnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
EOF

# Container entrypoint script
COPY <<'EOF' /usr/local/bin/start.sh
#!/bin/bash
set -e

# Make sure the legacy dir doesn't trigger the migration code
rm -rf /root/.vnc

# Clean up stale locks from previous runs
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

vncserver :1 -localhost no -SecurityTypes None -geometry 1024x768 \
    -xstartup /root/.config/tigervnc/xstartup --I-KNOW-THIS-IS-INSECURE

# Self-signed cert for noVNC
if [ ! -f /root/self.pem ]; then
    openssl req -new -subj "/C=JP" -x509 -days 365 -nodes \
        -out /root/self.pem -keyout /root/self.pem
fi

# Run websockify in the foreground so the container stays alive
exec websockify --web=/usr/share/novnc/ --cert=/root/self.pem 6080 localhost:5901
EOF

RUN chmod +x /root/.config/tigervnc/xstartup /usr/local/bin/start.sh \
    && touch /root/.Xauthority

EXPOSE 5901 6080

CMD ["/usr/local/bin/start.sh"]
