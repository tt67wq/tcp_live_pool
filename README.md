# TunnelEx: 一个简单的保活TCP连接池

## usage
1.
```
cd apps/local
iex -S mix
```
2
```
cd apps/server
iex -S mix
```

3. in local app
```
iex(1)> Local.TcpPool.send_data "hello"
response: hellotoo!
:ok
```


