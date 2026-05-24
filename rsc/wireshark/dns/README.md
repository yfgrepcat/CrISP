
Lauch packet capture in separate terminals in server DNS-AS12, NOMAD-CLIENT and TEST-SITE:
- DNS-AS12: 
```bash
docker exec -it clab-enterprise-ospf-bgp-dns-as12 tcpdump -ni eth1 -s 0 -w /tmp/dns-server.pcap udp port 53
```
- NOMAD-CLIENT:
```bash
docker exec -it clab-enterprise-ospf-bgp-NOMAD-CLIENT tcpdump -ni eth1 -s 0 -w /tmp/nomad-client-dns.pcap udp port 53
```
- TEST-SITE:
```bash
docker exec -it clab-enterprise-ospf-bgp-test-site tcpdump -ni eth1 -s 0 -w /tmp/test-client-dns.pcap udp port 53
```

From NOMAD-CLIENT, lauch tests:
```bash
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup www.enterprise.local 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup voip.enterprise.local 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup extranet.corentinpradier.com 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup voip.corentinpradier.com 120.0.34.7'
```
Result: 
```bash
t70n@t70n-workstation:~/Documents/enterprise-network$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup www.enterprise.local 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup voip.enterprise.local 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup extranet.corentinpradier.com 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup voip.corentinpradier.com 120.0.34.7'
Server:         120.0.34.7
Address:        120.0.34.7:53

Name:   www.enterprise.local
Address: 120.0.35.12


Server:         120.0.34.7
Address:        120.0.34.7:53

Name:   voip.enterprise.local
Address: 120.0.35.13


Server:         120.0.34.7
Address:        120.0.34.7:53

Name:   extranet.corentinpradier.com
Address: 172.20.20.34


Server:         120.0.34.7
Address:        120.0.34.7:53

Name:   intranet.corentinpradier.com
Address: 172.20.20.34


Server:         120.0.34.7
Address:        120.0.34.7:53

Name:   voip.corentinpradier.com
Address: 120.0.35.1


t70n@t70n-workstation:~/Documents/enterprise-network$ 
```

---

From TEST-SITE:
```bash
docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'nslookup intranet.corentinpradier.com 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://172.20.20.34'
```
Result:
```bash
t70n@t70n-workstation:~/Documents/enterprise-network$ docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'nslookup intranet.corentinpradier.com 120.0.34.7'
docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://172.20.20.34'
Server:         120.0.34.7
Address:        120.0.34.7:53

** server can't find intranet.corentinpradier.com: NXDOMAIN

** server can't find intranet.corentinpradier.com: NXDOMAIN

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Intranet - Corentin Pradier</title>
</head>
<body>
    <div id="login-container">
        <div id="login-form">
            <h2>Connexion Intranet</h2>
            <input type="text" id="username" placeholder="Nom d'utilisateur">
            <input type="password" id="password" placeholder="Mot de passe">
            <button onclick="login()">Se connecter</button>
            <p id="error-message" style="color: red;"></p>
        </div>
    </div>

    <div id="main-content" style="display: none">
        <h1>Page web des fans internes de Corentin Pradier, également connu sous le nom cocoaligot12 (12 comme l'aveyron)</h1>
        <img src="./images/corentinpradier.png">
    </div>

    <script>
        function login() {
            const user = document.getElementById('username').value;
            const pass = document.getElementById('password').value;

            // Oui oui la cybersécurité
            if (user === 'coco' && pass === 'aligot12') {
                document.getElementById('login-container').style.display = 'none';
                document.getElementById('main-content').style.display = 'block';
            } else {
                document.getElementById('error-message').innerText = 'Identifiants incorrects.';
            }
        }
    </script>
</body>
</html>
t70n@t70n-workstation:~/Documents/enterprise-network$ 
```

Then, simply stop captures from DNS-AS12 and NOMAD-CLIENT with ^C, and download capture files:
```bash
docker cp clab-enterprise-ospf-bgp-dns-as12:/tmp/dns-server.pcap .
docker cp clab-enterprise-ospf-bgp-NOMAD-CLIENT:/tmp/nomad-client-dns.pcap .
docker cp clab-enterprise-ospf-bgp-test-site:/tmp/test-client-dns.pcap .
```

Wireshark filters : 
- `dns`
- `udp.port == 53`
- `dns.flags.response == 1`
