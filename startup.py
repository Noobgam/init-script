import os, platform, distro, shutil
import sys
from jinja2 import Environment, FileSystemLoader

def execute(cmd):
    print('[INFO] Executing ' + cmd)
    return os.system(cmd)    

class Component():
    def __init__(self, name):
        self.name = name
   
    def dep_comps(self):
        return []

    def dep_pkgs(self):
        return []

    def install(self):
        print('[INFO] Installing component ' + self.name)

    # when installation requires user to specify something (e.g. host / port)
    def get_input(self, msg):
        return input("[INPUT {}] {}:".format(self.name, msg))


    def run(self):
        pass

class Docker(Component):
    def __init__(self):
        Component.__init__(self, 'Docker')

    def dep_pkgs(self):
        return ['apt-transport-https', 'ca-certificates', 'curl', 'gnupg-agent', 'software-properties-common']

    def install(self):
        Component.install(self)
        execute('curl -sSL https://get.docker.com | sh')

    def run(self):
        pass
    
    def descr(self):
        return '''Container service
Docker container engine, allows development of portable & scalable apps'''

"""
    Installs Zabbix agent on host
"""
class Zabbix(Component):
    def __init__(self):
        Component.__init__(self, 'Zabbix')

    def dep_comps(self):
        return []

    def dep_pkgs(self):
        return []    
        
    def install(self):
        Component.install(self)
        global workdir
        file_loader = FileSystemLoader(workdir)
        env = Environment(loader = file_loader)

        distr = distro.linux_distribution()        
        distrname = distr[-1]
        execute('wget https://repo.zabbix.com/zabbix/4.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.0-2+{}_all.deb'.format(distrname))
        execute('dpkg -i zabbix-release_4.0-2+{}_all.deb'.format(distrname))

        execute('apt update')
        # TODO(noobgam): install might fail for some odd reason
        # due to the fact that zabbix starts on installation, which might fail due to permissions (even though sudo (?!))
        # this is fixable by `mkdir -p /var/log/zabbix-agent && chown -c zabbix:zabbix /var/log/zabbix-agent
        # yet I'm unsure how to handle this correctly at the time.
        # perhaps the way to go is to ignore apt install failure and explicitly chown the folder.

        execute('apt install zabbix-agent -y')

        # This is really odd that I have to stop it when I haven't even started it
        # but it crashes badly otherwise if you start it second time without starting.

        execute('service zabbix-agent stop')
        cfg = env.get_template('configs/zabbix_agentd.conf.jinja')

        # TESTING:
        #  see above

        execute('mkdir -p /var/log/zabbix-agent')
        execute('chown -c zabbix:zabbix /var/log/zabbix-agent')

        # /TESTING

        hostlist = self.get_input('specify zabbix server hosts')
        hostname = self.get_input('specify zabbix server name')

        f = open('/etc/zabbix/zabbix_agentd.conf', 'w')
        f.write(cfg.render(hostlist=hostlist, hostname=hostname))
        f.close()

    def run(self):
        execute('service zabbix-agent start')

    def descr(self):
        return '''Zabbix agent
used for monitoring purposes, requires zabbix server & frontend installed somewhere'''

"""
    Installs tightvnc on host
"""
class VNC(Component):
    def __init__(self):
        Component.__init__(self, 'VNC')

    def dep_comps(slef):
        return []

    def dep_pkgs(self):
        # I literally have no idea whatsoever which of these is necessary, but removal of most of them leads to undesired side effects.
        return [
            'xserver-xorg-core', 'xserver-xorg-input-all', 'tightvncserver',
            'xserver-xorg-video-fbdev', 'libx11-6', 'x11-common', 'x11-utils',
            'x11-xkb-utils', 'x11-xserver-utils', 'xterm', 'lightdm',
            'openbox', 'gnome-panel', 'gnome-settings-daemon',
            'metacity', 'nautilus', 'gnome-terminal', 'ubuntu-desktop'
        ]

    def install(self):
        global workdir
        shutil.copytree(os.path.join(workdir, '.vnc'), '/home/noobgam/.vnc')
        execute('chown -R noobgam:nogroup /home/noobgam/.vnc')
        execute('chmod +x /home/noobgam/.vnc/xstartup')

    def run(self):
        execute('tightvncserver -geometry 1920x1080')

    def descr(self):
        return '''TightVNC server
Used to connect to remote desktop, via non-ssh way'''

ALL_COMPONENTS = [Docker(), Zabbix(), VNC()]

if __name__ == "__main__":
    if (os.getuid() != 0):
        print('This script must be run as root')
        exit(1)
    if len(sys.argv) > 1:
        global workdir
        workdir = sys.argv[1]
    install = input("Want to install anything? y(Y)/n(N)")
    if install in "nN":
        exit(0)
    while True:
        print('Avaliable components:')
        for component in ALL_COMPONENTS:
            print(component.name)
        install = input("What would you like to install?\n")
        parsed = list(map(lambda x: x.strip(), install.split(',')))
        print(parsed)
        error = False
        for word in parsed:
            matches = [x for x in ALL_COMPONENTS if word in x.name]
            if len(matches) == 0:
                print("[ERROR] Don't know what to do with {}".format(word))
                error = True
                break
            elif len(matches) > 1:
                matchNames = list(map(lambda x : x.name, matches))
                print('[ERROR] Conflicting components found, which of {} do you want to install?'.format(matchNames))
                error = True
                break

        if error:
            print('Some error occured, try again.')
        else:
            comps = []
            for word in parsed:
                matches = [x for x in ALL_COMPONENTS if word in x.name]
                comps.append(matches[0])
            deps = set()
            for comp in comps:
                deps = deps.union(comp.dep_pkgs())

            execute('apt install {} -y'.format(' '.join(deps)))
            for comp in comps:
                comp.install()
            for comp in comps:
                comp.run()
            break

