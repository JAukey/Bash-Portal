local ip_addr = ngx.var.remote_addr
local cmd="/usr/bin/bashportal clientsadd "..ip_addr
ngx.say("success")
os.execute(cmd)
