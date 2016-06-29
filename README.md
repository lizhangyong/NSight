#NSight

NSight是一个用于监控 Ngixn 运行状态，控制访问权限的开源项目。

 
#描述
Nginx 通常被用作反向代理服务器或者 Web 服务器，其负载和稳定性是大家最为关注的情况，NSight 是基于 [lua_nginx_module(openrestry)](http://openresty.org/en/)  而开发的 Nginx 状态监控应用，具有部署简单，性能折损低的特点。

#安装部署

1.需要将 [lua_nginx_module](https://github.com/openresty/lua-nginx-module) 和 [ngx_http_stub_status_module](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html) 这两个模块编译到 Nginx 中，由于过程比较复杂，建议直接安装和编译 [OpenResty](http://openresty.org/en/) 这个项目，

2.将 NSight 中的 lua 文件夹拷贝到 conf 同级目录，将 conf/NSight.conf 拷贝到 conf 目录下，并在 nginx.conf 目录

3. 启动 nginx

4. 在浏览器中输入 http://ip:port/status, 看是否有返回结果


#返回值释义

/status 返回结果如下：

    {
		"generation":1,

		"requests":{"current":0,"total":0,"success":0},

		"worker_count":2,

		"address":"127.0.0.1:80",

	"nginx_version":"1.9.7",

	"server_zones":{        # web 的状态

		"localhost":{

			"processing":0,

			"requests":2, 

			"discarded":0,

			"sent":1201,

			"received":708,

			"responses":{   # 请求的返回统计 

			"3xx":0,

			"4xx":1,

			"5xx":0,

			"1xx":0,

			"2xx":1

			}

		}

	},

	"timestamp":1467012689,

	"connections":{"active":1,"writing":1,"current":2,"idle":1,"reading":0},

	"upstreams":{           # 上游的状态

		"upstream_1":{

			"peers":[

				{

				"weight":1,  # 设置权重

				"id":0,

				"conns":0,

				"received":0,

				"fails":0,

				"current_weight":0,   # 当前的权重

				"effective_weight":1,

				"responses":[  # 上游状态返回统计

					"3xx":0,

					"4xx":1,

					"5xx":0,

					"1xx":0,

					"2xx":100

				],

				"requests":101,  #请求数

				"backup":false,  #是否是备用结点 

				"fail_timeout":10,

				"sent":0,

				"name":"10.16.10.12:82",

				"max_fails":1

				}

			]

		}

	}
	
}