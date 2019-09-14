import os, platform, distro

def execute(cmd):
    print('[INFO] Executing ' + cmd)
#    return os.system(cmd)    

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
        return input("[INPUT {self.name}] {msg}:")


    def run(self):
        pass

class Docker(Component):
    def __init__(self):
        Component.__init__(self, 'Docker')

    def dep_pkgs(self):
        return ['apt-transport-https', 'ca-certificates', 'curl', 'gnupg-agent', 'software-properties-common']

    def install(self):
        Component.install(self)
        distr = distro.linux_distribution()
        distrname = distr[-1]
        if distrname == "bionic":
            execute('curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -')
            execute('''sudo add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"''')
            execute('apt update')
            execute('apt install docker-ce docker-ce-cli containerd.io -y')
        else:
            raise Exception('Other distros are not supported for now')

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
        distr = distro.linux_distribution()        
        distrname = distr[-1]
        execute('wget https://repo.zabbix.com/zabbix/4.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.0-2+{distrname}_all.deb')
        execute('dpkg -i zabbix-release_4.0-2+{distrname}_all.deb')
        execute('apt update')
        execute('apt install zabbix-agent')

    def run(self):
        execute('service zabbix-agent start')

    def descr(self):
        return '''Zabbix agent
used for monitoring purposes, requires zabbix server & frontend installed somewhere'''
        

ALL_COMPONENTS = [Docker(), Zabbix()]

if __name__ == "__main__":
    if (os.getuid() != 0):
        print('This script must be run as root')
        exit(1)
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
                print("[ERROR] Don't know what to do with {word}")
                error = True
                break
            elif len(matches) > 1:
                matchNames = list(map(lambda x : x.name, matches))
                print('[ERROR] Conflicting components found, which of {matchNames} do you want to install?')
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

            execute('apt install {}'.format(' '.join(deps)))
            break
