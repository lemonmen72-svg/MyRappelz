import json, sys
p=sys.argv[1]; d=json.load(open(p))
def one(v): return json.dumps(v, ensure_ascii=False)
out=['{']
keys=list(d.keys())
for ki,k in enumerate(keys):
    v=d[k]; comma=',' if ki<len(keys)-1 else ''
    if isinstance(v,list) and v and isinstance(v[0],(dict,list)):
        out.append('\t%s: [' % one(k))
        for i,e in enumerate(v):
            out.append('\t\t%s%s' % (one(e), ',' if i<len(v)-1 else ''))
        out.append('\t]'+comma)
    elif isinstance(v,dict) and any(isinstance(x,(dict,list)) for x in v.values()) and len(one(v))>110:
        out.append('\t%s: {' % one(k))
        ks=list(v.keys())
        for i,kk in enumerate(ks):
            out.append('\t\t%s: %s%s' % (one(kk), one(v[kk]), ',' if i<len(ks)-1 else ''))
        out.append('\t}'+comma)
    else:
        out.append('\t%s: %s%s' % (one(k), one(v), comma))
out.append('}')
open(p,'w').write('\n'.join(out)+'\n')
