# intralux.angra.local — vsftpd Configuration
### Nginx web server + vsftpd FTP | Amazon Linux 2023 | PRIVATE-1 (172.16.128.102)

---

## vsftpd — `/etc/vsftpd.conf`

```ini
# Run as standalone daemon (not via inetd)
listen=NO

# Listen on IPv6 (also accepts IPv4 connections)
listen_ipv6=YES

# Disable anonymous FTP access
anonymous_enable=NO

# Allow local system users to log in
local_enable=YES

# Allow write operations (upload, delete, rename)
write_enable=YES

# Enable directory change messages
dirmessage_enable=YES

# Display directory listings in local server time
use_localtime=YES

# Log all uploads and downloads
xferlog_enable=YES

# Ensure data connections originate from port 20
connect_from_port_20=YES

# Chroot local users to their home directory
chroot_local_user=YES

# Required secure chroot directory (must exist and be non-writable)
secure_chroot_dir=/var/lib/vsftpd/empty

# PAM service name
pam_service_name=vsftpd

# SSL certificate and key (issued by internal CA on srv.pdl.local)
rsa_cert_file=/etc/nginx/ssl/intranet.angra.local.crt
rsa_private_key_file=/etc/nginx/ssl/intranet.angra.local.key

# Enable SSL
ssl_enable=YES

# Default root directory for local users
local_root=/var/www/

# Allow write access even when users are chroot'd
allow_writeable_chroot=YES

# Passive mode port range (must be open in security group)
pasv_min_port=40000
pasv_max_port=50000

# Require SSL for both login and data connections
force_local_data_ssl=YES
force_local_logins_ssl=YES

# Allow only TLS — disable older SSL versions
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
```

---

## Notes

- The FTP root `/var/www/` covers both the HTTP root (`/var/www/html`) and HTTPS root (`/var/www/htmls`)
- The SSL certificate is shared with Nginx — issued by the CA on `srv.pdl.local`
- Passive mode ports `40000–50000` must be allowed in the instance security group
- Both plain FTP and FTPS (implicit TLS) are tested from `cli.pdl.local` via FileZilla
- Note: `secure_chroot_dir` differs from `dmzlux.pdl.local` — Amazon Linux uses `/var/lib/vsftpd/empty`
