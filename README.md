Bashportal is a simple bash script which provide
restricted access to an internet connection.

nginx server config example:

port=2561
host=wifi or "gateway ip"

server {
	listen       2561;
	server_name  localhost;
    resolver 127.0.0.1; 
	location /portal {
		alias /etc/bashportal/html;
	}
	location /lua {
		content_by_lua_file /etc/bashportal/html/lua/portal.lua;
		}
	location / {
        rewrite ^(.*)$ http://wifi.lan:2561/portal;
        }
}
