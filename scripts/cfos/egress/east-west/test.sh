[ok]k exec -it po/diag100 -n app-2 -- curl   http://10.1.200.21
[blocked] k exec -it po/diag100 -n app-2  -- curl  -H "User-Agent: () { :; }; /bin/ls" http://10.1.200.21


