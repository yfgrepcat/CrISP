$TTL 3600
@ IN SOA ns.corentinpradier.com. admin.corentinpradier.com. (
    2026052202
    7200
    1800
    604800
    3600
)

@       IN NS    ns.corentinpradier.com.
ns      IN A     120.0.36.1
intranet IN A    120.0.40.3
extranet IN A    120.0.40.3
voip     IN A     120.0.40.5
; end of zone
