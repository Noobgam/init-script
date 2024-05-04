import logging
import os
import shutil
import sys

logging.basicConfig(
    format="%(asctime)s %(levelname)-8s %(message)s",
    level=logging.DEBUG,
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger()


def execute(cmd):
    logger.info("Executing " + cmd)
    return os.system(cmd)


SAMPLE_NGINX_CONF = """server {{

    location / {{
        proxy_pass http://127.0.0.1:9001/;
    }}

    server_name {domain};

    listen [::]:80 ipv6only=on;
    listen 80;

}}"""


class Component:
    def __init__(self, name):
        self.name = name

    def dep_comps(self):
        return []

    def dep_pkgs(self):
        return []

    def install(self):
        logger.info("Installing component " + self.name)

    # when installation requires user to specify something (e.g. host / port)
    def get_input(self, msg):
        return input("[INPUT {}] {}:".format(self.name, msg))

    def run(self):
        pass


class NginxDomain(Component):
    domain: str

    def __init__(self):
        Component.__init__(self, "NginxDomain")

    def dep_pkgs(self):
        return ["certbot", "python3-certbot-nginx", "nginx"]

    def install(self):
        Component.install(self)
        self.domain = self.get_input("Insert your fqdn")
        with open("/etc/nginx/sites-enabled/default", "w") as f:
            f.write(SAMPLE_NGINX_CONF.format(domain=self.domain))

    def run(self):
        execute("systemctl reload nginx")
        execute(f"certbot --nginx -d {self.domain}")

    def descr(self):
        return """Bootstraps nginx + asks you for your domain to obtain the certificate from certbot"""


class Docker(Component):
    def __init__(self):
        Component.__init__(self, "Docker")

    def dep_pkgs(self):
        return [
            "apt-transport-https",
            "ca-certificates",
            "curl",
            "gnupg-agent",
            "software-properties-common",
        ]

    def install(self):
        Component.install(self)
        execute("curl -sSL https://get.docker.com | sh")
        # add noobgam to docker group for convenience
        execute("usermod -aG docker noobgam")

    def run(self):
        pass

    def descr(self):
        return """Container service
Docker container engine, allows development of portable & scalable apps"""


class AWSCLI(Component):
    def __init__(self):
        Component.__init__(self, "AWSCLI")

    def dep_pkgs(self):
        return ["curl", "python3-pip", "unzip"]

    def install(self):
        Component.install(self)
        execute("curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip")
        execute("unzip awscliv2.zip")
        execute("./aws/install")
        execute("rm -rf awscliv2.zip aws")

    def run(self):
        execute("sudo -u noobgam aws configure")

    def descr(self):
        return "AWS Command Line Interface\nAllows managing AWS services directly from the terminal"


class NodeExporter(Component):
    def __init__(self):
        Component.__init__(self, "NodeExporter")

    def dep_pkgs(self):
        return ["wget", "tar"]

    def install(self):
        Component.install(self)
        execute("wget https://github.com/prometheus/node_exporter/releases/download/v1.8.0/node_exporter-1.8.0.linux-amd64.tar.gz")
        execute("tar -xvf node_exporter-1.8.0.linux-amd64.tar.gz")
        execute("mv node_exporter-1.8.0.linux-amd64/node_exporter /bin/")
        execute("rm -rf node_exporter-1.8.0.linux-amd64.tar.gz node_exporter-1.8.0.linux-amd64")

    def setup_service(self):
        service_content = f"""\
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
Restart=always
ExecStart=/bin/node_exporter

[Install]
WantedBy=multi-user.target
"""
        with open("/etc/systemd/system/node_exporter.service", "w") as f:
            f.write(service_content)

    def run(self):
        self.setup_service()
        execute("systemctl daemon-reload")
        execute("systemctl enable node_exporter")
        execute("systemctl start node_exporter")

    def descr(self):
        return "Node exporter setup"


class VNC(Component):
    """
    Installs tightvnc on host
    """

    def __init__(self):
        Component.__init__(self, "VNC")

    def dep_comps(slef):
        return []

    def dep_pkgs(self):
        # I literally have no idea whatsoever which of these is necessary, but removal of most of them leads to undesired side effects.
        return [
            "xserver-xorg-core",
            "xserver-xorg-input-all",
            "tightvncserver",
            "xserver-xorg-video-fbdev",
            "libx11-6",
            "x11-common",
            "x11-utils",
            "x11-xkb-utils",
            "x11-xserver-utils",
            "xterm",
            "lightdm",
            "openbox",
            "gnome-panel",
            "gnome-settings-daemon",
            "metacity",
            "nautilus",
            "gnome-terminal",
            "ubuntu-desktop",
            "terminator",
        ]

    def install(self):
        global workdir
        shutil.copytree(os.path.join(workdir, ".vnc"), "/home/noobgam/.vnc")
        execute("chown -R noobgam:nogroup /home/noobgam/.vnc")
        execute("chmod +x /home/noobgam/.vnc/xstartup")

    def run(self):
        execute("tightvncserver -geometry 1920x1080")

    def descr(self):
        return """TightVNC server
Used to connect to remote desktop, via non-ssh way"""


ALL_COMPONENTS = [Docker(), NginxDomain(), VNC(), AWSCLI(), NodeExporter()]

if __name__ == "__main__":
    if os.getuid() != 0:
        logger.error("This script must be run as root")
        exit(1)
    if len(sys.argv) > 1:
        global workdir
        workdir = sys.argv[1]
    install = input("Want to install anything? y(Y)/n(N)")
    if install in "nN":
        exit(0)
    while True:
        logger.info(f"Avaliable components: {', '.join([component.name for component in ALL_COMPONENTS])}")
        install = input("What would you like to install?\n")
        parsed = list(map(lambda x: x.strip(), install.split(",")))
        logger.info(parsed)
        error = False
        for word in parsed:
            matches = [x for x in ALL_COMPONENTS if word in x.name]
            if len(matches) == 0:
                logger.error("Don't know what to do with {}".format(word))
                error = True
                break
            elif len(matches) > 1:
                matchNames = list(map(lambda x: x.name, matches))
                logger.error(
                    "Conflicting components found, which of {} do you want to install?".format(
                        matchNames
                    )
                )
                error = True
                break

        if error:
            print("Some error occurred, try again.")
        else:
            comps = []
            for word in parsed:
                matches = [x for x in ALL_COMPONENTS if word in x.name]
                comps.append(matches[0])
            deps = set()
            for comp in comps:
                deps = deps.union(comp.dep_pkgs())

            execute("apt install {} -y".format(" ".join(deps)))
            for comp in comps:
                comp.install()
            for comp in comps:
                comp.run()
            break
