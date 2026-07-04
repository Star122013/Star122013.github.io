#import "../_template.typ": *

#show: post.with(
  title: "Use NixOS as a network router ",
  date: datetime(year: 2026, month: 7, day: 4),
  tags: ("NixOS", "Network"),
  description: "Building a network router with NixOS.",
)

= Use NixOS as a network router

As usual, if we talk about building a network router, we will think about #link("https://openwrt.org/")[OpenWrt], #link("https://mikrotik.com/software")[RouterOS] or some projects using #link("https://ebpf.io/")[ebpf] such as #link("https://landscape.whileaway.dev/")[landscape]. In the past I used *landscape* to be my network router, it's a very very powerful software. But there are some features I don't use. What I need is only a minimal router that can reduce ads and provide tproxy. So I learned a little knowledge about Linux network and build a router with NixOS by myself.

== Why NixOS
Firstly, I prefer a stable Linux distribution over a rolling-release one like Arch for my router, as it requires less maintenance and fewer updates over the long run. Secondly, I'm interested in some distributions known as *immutable distros*#footnote[https://www.fosslinux.com/137025/best-future-proof-immutable-linux-distributions.htm] such as #link("https://fedoraproject.org/atomic-desktops/")[Fedora Atomic] and #link("https://nixos.org/")[NixOS]. I was impressed by their *declarative configuration capabilities* . Most importantly, I have used NixOS for a long time and I even have a machine using fedora-bootc that I build myself. Therefore, for a perfect balance, I chose NixOS to serve as my network router.

== What I Use
- *systemd-networkd*: a system daemon that manages network configurations.
- *nftables*: the modern Linux kernel packet classification framework.
- *iproute2*: a collection of userspace utilities for controlling and monitoring various aspects of networking in the Linux kernel.
- *AdguardHome*: providing dns and dhcp services and reducing ads.
- *sing-box*: providing tproxy.

== How To do
=== Use Systemd-networkd To Config Network Interface
Because I don't use ipv6, steps below this only support ipv4.\
Base configuration is here:
```nix
networking = {
  enableIPv6 = false;
  networkmanager.enable = false;
  useDHCP = false;
  resolvconf.useLocalResolver = false;
  firewall.enable = false;
  nameservers = [ "127.0.0.1" ];
};
```
`firewall.enable` is false because nftables can do better than it.\
Before using systemd-networkd, close the NetworkManager if using it.
```nix
networking.networkmanager.enable = false;
```
Then enable the systemd-networkd and config wan and lan network.
```nix
systemd = {
  network = {
    enable = true;
    networks = {
      "10-wan" = {
        matchConfig.Name = net.wanInterface;
        networkConfig = {
          Description = "WAN";
          DHCP = "yes";
        };
      };

      "10-lan" = {
        matchConfig.Name = net.lanInterface;
        networkConfig = {
          Description = "LAN (USB NIC)";
          Address = net.lanAddress;
          IPMasquerade = "both";
        };
        linkConfig.RequiredForOnline = true;
      };
    };
  };
};
```
`net.wanInterface` and `net.lanInterface` are interfaces that can be found using command `ip a`.
=== Write AdguardHome Configuration To Turn On DNS and DHCP Service.
Firstly, turn off systemd-resolved.
```nix
services.resolved.enable = false;
```
Then write AdguardHome configuration.
```nix
{ pkgs, ... }:

let
  net = import ./net.nix;

  # server=/domain/upstream → [/domain/]upstream
  chinaListSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf";
    hash = "sha256-vtOhXaB5/zdKnPdDMN2ArhGg68P8ODr5ULtE44CXsW4=";
  };

  # chinese sites dnspod + alidns
  chinaUpstreamFile = pkgs.runCommand "china-upstream.txt" { } ''
    awk -F/ '{printf "[/%s/]https://sm2.doh.pub/dns-query https://dns.alidns.com/dns-query\n", $2}' \
      < ${chinaListSrc} > $out
    # non-chinese.
    echo "https://1.1.1.1/dns-query" >> $out
    echo "https://8.8.8.8/dns-query" >> $out
  '';
in
{
  systemd.services.adguardhome = {
    after = [
      net.lanDevice
      "network-online.target"
    ];
    wants = [
      net.lanDevice
      "network-online.target"
    ];
  };

  services.adguardhome = {
    enable = true;

    # Allow web-UI tweaks (blocklists, per-client rules, custom upstreams)
    # to persist at runtime. Trade-off: any change made in the UI overrides
    # what we set here on the next `nh os switch` unless the user edits
    # this file too. For a home router this is the right default — no one
    # wants to `nh os switch` just to add a blocklist.
    mutableSettings = true;

    # The NixOS firewall (`networking.firewall`) is disabled in network.nix
    # in favour of hand-rolled nftables, so this option would do nothing.
    openFirewall = false;

    settings = {
      # ---- DNS server ----
      dns = {
        bind_hosts = [
          net.lanIp
          "127.0.0.1"
        ];
        port = 53;

        upstream_dns = [
          "https://1.1.1.1/dns-query"
          "https://8.8.8.8/dns-query"
        ];

        upstream_dns_file = "${chinaUpstreamFile}";

        # bootstrap_dns
        bootstrap_dns = [
          "223.5.5.5"
          "1.1.1.1"
        ];

        protection_enabled = true;

        filtering = {
          protection_enabled = true;
          filters_update_interval = 24; # hours
          filters = [
            {
              enabled = true;
              id = 1;
              url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
              name = "AdGuard DNS filter";
            }
            {
              enabled = true;
              id = 2;
              url = "https://anti-ad.net/easylist.txt";
              name = "Anti-AD";
            }
          ];
        };

        cache_size = 4194304; # 4 MiB (AGH default)
      };

      # ---- DHCP server ----
      dhcp = {
        enabled = true;
        interface_name = net.lanInterface;

        # DHCPv4 — fields go under dhcpv4, not at the top level, since
        # AGH 0.107.77 (schema_version >= 27).
        dhcpv4 = {
          gateway_ip = net.lanIp;
          subnet_mask = "255.255.255.0";
          range_start = "10.10.10.2";
          range_end = "10.10.10.100";
          lease_duration = 4000; # seconds; matches the old kea setting
        };

        # DHCPv6 — explicitly disabled to avoid the "neither dhcpv4 nor
        # dhcpv6 srv is configured" fatal error.
        dhcpv6 = {
          range_start = "";
        };
      };

      # ---- Web UI (LAN only) ----
      web = {
        bind_host = net.lanIp;
        port = 3000;
      };

      # ---- Misc ----
      users = [ ]; # no auth — LAN-only; the nftables filter blocks WAN
      querylog_enabled = true;
      querylog_interval = 90; # days of query log retention
    };
  };
}
```
After writing these, the AdguardHome will make the router work well.
=== Tproxy
Using tproxy has many methods such as nftables or ebpf, here use nftables and singbox#footnote[Maybe I will write an ebpf project to replace it].\
Some nftables rules are below:
```nix
networking.nftables = {
  enable = true;
  tables = {
    # WAN: only accept established, related and lan.
    filter = {
      enable = true;
      name = "filter";
      family = "inet";
      content = ''
        chain input {
          type filter hook input priority 0; policy accept;

          ct state { established, related } accept
          iifname "lo" accept
          iifname ${net.lanInterface} accept
          iifname ${net.wanInterface} drop
        }

        chain forward {
          type filter hook forward priority 0; policy accept;

          ct state { established, related } accept
          iifname ${net.lanInterface} oifname ${net.wanInterface} accept
          iifname ${net.wanInterface} drop
        }
      '';
    };
    # DNS: avoid applications set dns server by themselves.
    dns-nat = {
      enable = true;
      name = "dns-nat";
      family = "inet";
      content = ''
        chain prerouting {
          type nat hook prerouting priority -100; policy accept;

          iifname ${net.lanInterface} udp dport 53 ip daddr != ${net.lanIp} redirect to 53
          iifname ${net.lanInterface} tcp dport 53 ip daddr != ${net.lanIp} redirect to 53
        }
      '';
    };
    # Tproxy
    singbox = {
      enable = true;
      name = "singbox";
      family = "inet";
      content = ''
        chain prerouting {
          type filter hook prerouting priority -150; policy accept;

          meta mark 1234 accept                               # skip that sing-box has solved
          ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } accept
          ip6 daddr { ::1, fc00::/7 } accept                  # localhost

          meta l4proto tcp meta mark set 1 tproxy to :12345 accept   # TCP → TProxy + set mark
          udp dport 443 drop;                                 # ban QUIC/HTTP3
        }
        chain output {
          type route hook output priority -150; policy accept;

          meta mark 1234 accept
          meta skgid == 999 accept                            # skip sing-box self
          ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } accept
          meta l4proto tcp meta mark set 1 accept             # TCP  → lo → PREROUTING TProxy
        }
      '';
    };
  };
};
```
And need iproute2 to solve local packets.
```nix
systemd.services = {
  iproute-singbox = {
    enable = true;
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 ];
    script = ''
      grep -q "^100 singbox$" /etc/iproute2/rt_tables || echo "100 singbox" >> /etc/iproute2/rt_tables

      ip -4 rule add fwmark 1 lookup singbox priority 100 2>/dev/null || true
      ip -4 route add local 0.0.0.0/0 dev lo table singbox 2>/dev/null || true
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
    };
  };
};
```
This step routes the packets sent by the router itself to loopback, so they can be processed by the prerouting rules.

== Summary
After writing these and sing-box config, a network router will work.
Below is the network topology diagram.
#figure(
  image("network.png", width: 80%),
  caption: [
    Network Topology Diagram
  ],
)
