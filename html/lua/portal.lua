local ip_addr = ngx.var.remote_addr
local cmd="/usr/bin/bashportal clientsadd "..ip_addr
os.execute(cmd)
