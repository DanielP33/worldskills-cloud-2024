# srv.angra.local — Nginx Configuration
### NAT server + Nginx web server | Amazon Linux 2023 | PUBLIC (172.16.0.100)

---

## Nginx — `/etc/nginx/nginx.conf`

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;

    # HTTP server — port 80
    server {
        listen       80;
        listen       [::]:80;
        server_name  www.eppv.pt;
        root         /var/www/html;
        index        index.html info.php index.php all.html;

        location ~ \.php$ {
            include /etc/nginx/fastcgi_params;
            fastcgi_pass unix:/var/run/php-fpm/www.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }

        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html { }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html { }
    }

    # HTTPS server — port 443
    server {
        listen       443 ssl;
        listen       [::]:443 ssl;
        http2        on;
        server_name  www.eppv.pt;
        root         /var/www/htmls;
        index        index.html info.php index.php all.html;

        # Certificate issued by internal CA on srv.pdl.local
        ssl_certificate     "/etc/nginx/ssl/www.eppv.pt.crt";
        ssl_certificate_key "/etc/nginx/ssl/www.eppv.pt.key";
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout  10m;
        ssl_ciphers PROFILE=SYSTEM;
        ssl_prefer_server_ciphers on;

        location ~ \.php$ {
            include /etc/nginx/fastcgi_params;
            fastcgi_pass unix:/var/run/php-fpm/www.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }

        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html { }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html { }
    }
}
```

---

## Notes

- HTTP root: `/var/www/html`
- HTTPS root: `/var/www/htmls`
- `www.eppv.pt` is served directly from this machine — no load balancer in front of it
- Accessible from the internet and from `cli.angra.local` via the public IP of `srv.angra.local`
- `cli.angra.local` resolves `www.eppv.pt` via Route 53 → `srv.angra.local` public IP (A record)
- The `www.eppv.pt` certificate is issued by the CA on `srv.pdl.local` and copied over during setup
- PHP-FPM must be installed and running (`php-fpm` service)
- Web content cloned from `https://github.com/jdmedeiros/cc2024` and customised
- This machine also handles NAT for `angra-vpc` private subnets — IP forwarding and iptables NAT rules must be configured
