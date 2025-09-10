## Introduction

In July 2025 the British government brought in the 'Online Safety Act', which
introduced mandatory age verification on most social media sites. Lots of people,
including myself, do not like the idea of uploading our identity documents to
some unknown entity, as this could enable identity theft in the event of a data breach.

In this guide, we describe how to appear as an internet user of another country,
and thus bypassing oppressive internet laws, by setting up our own VPN, or Virtual Private
Network, and automatically routing all of our traffic through it.

### What is a VPN?

What is a VPN? At its simplest, a VPN allows a client to connect to another internal network
as if it was inside that network, through the internet. Thus traffic is routed through that
network instead of its 'real' network. Popular VPN technologies include OpenVPN, and more recently
Wireguard, we are going to use the latter due to its simplicity and ease of use.

### PfSense

We want all clients in our home network to have their social media traffic routed through the VPN
automatically, without needing to install any client app on our devices. To do this, our router
*itself* will become the VPN client, and we can set which traffic goes through the VPN with rules on
our router. 

This guide teaches how to achieve this on Pfsense, probably the most popular open source router
software at the moment, but it is also possible on alternatives such as OpenSense or OpenWRT.

## Installing wireguard on the server

### Installing dependencies

```
sudo apt update && sudo apt install wireguard git qrencode
```

### Setting up the wireguard configuration

Setting up wireguard peers and keypairs can be a little bit tricky. We will use a small script to do
this for us. It generates new keypairs automatically every time. This script also generates a pre-shared key,
an optional extra layer of symmetric-key cryptography which helps protect against quantum-computers!

```
git clone https://github.com/jwansek/wireguard-config-generator.git && cd wireguard-config-generator/
```

Before running the script, take note of the main network interface and the public IP address, by using
the `ip a` command. In this example, the main interface is called `eth0` and the public IP address is `84.32.34.20`.

```
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 54:52:00:5e:85:38 brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    altname ens3
    inet 84.32.34.20/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::5652:ff:fe5e:8538/64 scope link 
       valid_lft forever preferred_lft forever
```

Now we run the script. Whilst we only need one client peer for our router, it is 
recommended to generate a few extra for testing or for mobile devices that we can use
when away from home. 

We can optionally set a domain name for our VPN server, but this is not strictly necessary, we can just use the
plain IP address. We also set the DNS server for our clients to use, in this example we use 
Google DNS at `8.8.8.8`.

```
# bash wireguard-config-generator.sh 
Server public IP: 84.32.34.20
Server domain name (optional): 84.32.34.20
Number of clients (maximum 254): 3
Client DNS: 8.8.8.8
Main interface name (e.g. eth0): eth0
generating server config
Generating client config with IP 10.13.37.2
Generating client config with IP 10.13.37.3
Generating client config with IP 10.13.37.4
```

### Starting the wireguard daemon

Our generated configs are in the `wgconfigs/` directory. The server configuration
file is called `wg0.conf` and the client peer configurations are in the `clientconfigs/`
directory. We copy the server configuration over and then start the daemon (service).

```
cd wgconfigs/
sudo cp wg0.conf /etc/wireguard/
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

We also need to enable IP port forwarding:

```
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Testing

Before setting up the PfSense client, it is prudent to test the wireguard server is working.
It is very quick and easy to do this.

#### Testing on a phone

Using the wireguard app, we can scan a QR code configuration file. We can generate a QR code
by using the command:

```
sudo qrencode -t ansiutf8 < wg0c2.conf
```

#### Testing on GNU/Linux

Bring up wireguard tunnels using the `wg-quick` command, on your local machine:

```
sudo wg-quick up ./wg0c2.conf
```

Then we can use a website such as [ipleak.net](https://ipleak.net) to test if our IP
address has changed:

![Testing if your IP address has changed](https://i.imgur.com/v2Yfoou.jpeg)

If the IP address and location is different to your real IP address and location, it indicates
that the wireguard server is working correctly. You can also use the `wg` command on the server
to get the status of peers:

```
# sudo wg
interface: wg0
  public key: UI7hP30s4ZJKsG2v3aGIEupAfUcWWmWmXKmSn4ha+SA=
  private key: (hidden)
  listening port: 51820

peer: vD1023QUDVHK5n5iVDFsvqg6pr04hY0DR6aYWeFU6wo=
  preshared key: (hidden)
  endpoint: 82.**.**.**:48635
  allowed ips: 10.13.37.2/32
  latest handshake: 1 minute, 6 seconds ago
  transfer: 9.56 MiB received, 210.92 MiB sent

peer: me6gO7rT5TvVxRKIO1sOgn6fN6LR/u0p2KLwckBcWVQ=
  preshared key: (hidden)
  allowed ips: 10.13.37.3/32

peer: nGfn+YIGS0el4sZEvsoROngY1ULP6lVv3hzj3fpI7mc=
  preshared key: (hidden)
  allowed ips: 10.13.37.4/32
```

## PfSense wireguard client configuration

In this tutorial, we use the second wireguard peer, which for us looks like the following:

```
# cat wg0c3.conf 
[Interface]
Address = 10.13.37.3/32
PrivateKey = IP9Bx3NqyfSoYrhEXrWp8uvA/ByiDV5Rs0XkUl2cRmQ=
DNS = 8.8.8.8

[Peer]
PublicKey = UI7hP30s4ZJKsG2v3aGIEupAfUcWWmWmXKmSn4ha+SA=
PresharedKey = Nr4CZb4RWNQ+vc6b8v68invGdXjFPi5t72soAQuhALA=
Endpoint = 84.32.34.20:51820
AllowedIPs = 0.0.0.0/0
```

First we need to install the wireguard package if we haven't already. System > Package Manager > Avaliable Packages
then click 'Install' next to wireguard.

Then VPN > WireGuard to configure wireguard. 

### Tunnel configuration

Set a description and fill in the private key (ours is `IP9Bx3NqyfSoYrhEXrWp8uvA/ByiDV5Rs0XkUl2cRmQ=`), then Save. It is not necessary to touch any other setting.

![PfSense tunnel configuration](https://i.imgur.com/rOJXmjG.png)

A note that by default, keys are hidden for security, but they are shown in this tutorial to make it clearer.

### Peer configuration

Select the previously created tunnel, set an appropriate description, uncheck 'Dynamic Endpoint' which
will make the 'Endpoint' and 'Port' options avaliable, populate them with the server IP and port, which for us
are `84.32.34.20` and `51820` respectively. Then set the 'Public Key' from the configuration file,
`UI7hP30s4ZJKsG2v3aGIEupAfUcWWmWmXKmSn4ha` and the pre-shared key, `Nr4CZb4RWNQ+vc6b8v68invGdXjFPi5t72soAQuhALA=`.
Under 'Allowed IPs', set it to `0.0.0.0/0` since we will set the policy routing later. Then save the peer.

![PfSense peer configuration](https://i.imgur.com/GZhgzaK.png)

### Starting the wireguard service

The wireguard service is not running by default. Click 'Enable' under 'Settings', then 'Save' and apply changes.

### Setting up the gateway

Under System > Routing > Gateways, select 'WAN_DHCP' under 'Default gateway' so that the wireguard gateway isn't
used before it's ready. Then save and apply.

Under Interfaces > Assignments, select `tun_wg0` under 'Avaliable network ports' then click 'Add'. Then click on
the new interface, which will be called `OPT` or `OPT2` or similar. From top to bottom, fill in the following:

- Enable the interface
- Set an appropriate description
- Select 'Static IPv4' under 'IPv4 Configuration Type'
- Under IPv4 address, set the address from the config file. Ours is `10.13.37.3/32`.
- Click 'Add a new gateway'. Give it a name and input the same IP address as before.
- Then 'Save' and 'Apply'.

![Setting up the interface assignment](https://i.imgur.com/JwL2S2V.png)

![Setting up the gateway](https://i.imgur.com/aLvcFjj.png)

### Enabling outbound NAT

Under Firewall > NAT > Outbound, select "Hybrid Outbound NAT" then Save and Apply.

Click add a rule to the top. Under 'Interface', select the new interface you just made,
under 'Address Family' select 'IPv4', and under 'Source' select 'LAN subnets'. Then set
an appropriate description and Save and Apply.

![Outbound NAT rules](https://i.imgur.com/wxbKYVv.png)

### Policy routing

This is it! We are now going to set rules to route traffic through the VPN. We are going to tell
the router to put **ALL** traffic through the VPN, so we can test it works. 

Under Firewall > Rules > LAN, "Add" a new rule to the top.

- Under 'Interface' select 'LAN'
- Under 'Address Family' select 'IPv4'
- Under 'Protocol' select 'Any'- be careful here- the default is TCP.
- Under 'Extra Options', select 'Display Advanced' and towards the bottom, select our VPN gateway under 'Gateway'
- Then Save and Apply

![Policy routing 1.1](https://i.imgur.com/iKVCEoy.png)

![Policy routing 1.2](https://i.imgur.com/GegzRla.png)

### Testing

The VPN should now be configured. You can now test it with a bunch of IP checkers: [ipaddress.my](https://www.ipaddress.my/), [nordvpn.com/what-is-my-ip](https://nordvpn.com/what-is-my-ip/), [ipinfo.io/what-is-my-ip](https://ipinfo.io/what-is-my-ip), [ipleak.net](https://ipleak.net), and making sure your IP address and location isn't the real one.

Another thing you can try doing is SSHing into the wireguard server through the wireguard connection: `ssh 10.13.37.1`.

You can *also* test it by running `traceroute`. If the first hop is to the VPN server `10.13.37.1` instead of the router address, something like `192.168.1.1`, it indicates the clients are routing successfully.

```
$ traceroute twitter.com
traceroute to twitter.com (162.159.140.229), 64 hops max
  1   10.13.37.1  102.581ms  101.579ms  98.998ms 
  2   185.8.107.28  104.120ms  101.787ms  103.282ms
```

## Conclusion

We have set up our router so that all of our traffic on our local network will be routed through our VPN server. This means we don't need to install any VPN client software on our devices! And since we made some spare peers, we can use the VPN when away from the home too.

Creating our own VPN server has the advantage that we have it all to ourselves, meaning no unexpected slowdowns! And since we created it ourself, we can be certain of the security and that there is no logging.




