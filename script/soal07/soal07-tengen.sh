#!/bin/bash
# Soal 7 - tengen: ringkasan lease aktif dari /var/lib/dhcp/dhcpd.leases
# (entri terakhir per IP yang berlaku; fixed-address kugisaki tidak dicatat di file ini)
awk '
/^lease /            { ip=$2; state=""; mac=""; ends="" }
/^  ends /           { ends=$3" "$4; sub(";","",ends) }
/^  binding state /  { state=$3; sub(";","",state) }
/hardware ethernet / { mac=$3; sub(";","",mac) }
/^}/                 { if (ip!="") { S[ip]=state; M[ip]=mac; E[ip]=ends } }
END { for (i in S) printf "%-15s %-18s %-7s ends %s UTC\n", i, M[i], S[i], E[i] }
' /var/lib/dhcp/dhcpd.leases | sort -t. -k3,3n -k4,4n
