const fs=require('fs'),dir=require("path").join(__dirname,"..");
function load(f){return eval("(function(){"+fs.readFileSync(dir+"/"+f,"utf8").replace(".pragma library","")+";return {"+(f=="Model.js"?"parseDesktops,iconSource,build,validName":"apps,bundles")+"}})()")}
const M=load("Model.js"),C=load("Catalog.js");
const assert=require('assert');
const d=M.parseDesktops("gimp\tgimp\tgimp\t0\nfoo\tbar\t/usr/share/x/a.png\t0\nfoo\tfoo\t../x\t1\nbad pkg\tx\ty\t0\nbtop\tbtop\tbtop\t1\nx\t-rf\ty\t0\nz\tz\t/etc/passwd\t0\n");
assert.equal(d.gimp.launch,"gimp"); assert.equal(d.foo.id,"foo"); assert.equal(d.foo.launch,""); assert.equal(d.foo.icon,"");
assert.equal(d.btop.launch,""); assert(!d.x); assert(!d["bad pkg"]); assert.equal(d.z.icon,"");
assert.equal(M.iconSource("/usr/share/x/a.png"),"file:///usr/share/x/a.png"); assert.equal(M.iconSource("/usr/../etc/a.png"),"");
const repo=["neovim","helix","gimp"].map(n=>({n,r:"extra",v:"1",s:1048576*10,d:""}));
const idx={};repo.forEach((r,i)=>idx[r.n]=i);
const rows=M.build({catalog:C.apps,bundles:C.bundles,desktops:d,category:"Bundles",filter:"",repo,repoIndex:idx,installed:{neovim:true},explicit:{},updates:{},aurEnabled:false,aurResults:[],sort:"Default",limit:50});
console.log(rows.map(r=>r.label+" | "+r.meta+" | "+r.d+" | inst="+r.installed).join("\n"));
assert.equal(rows[0].members.filter(m=>!m.installed).length,1);
const f=M.build({catalog:C.apps,bundles:C.bundles,desktops:d,category:"Featured",filter:"",repo,repoIndex:idx,installed:{gimp:true},explicit:{},updates:{},aurEnabled:false,aurResults:[],sort:"Default",limit:50});
const g=f.find(r=>r.p=="gimp"); assert.equal(g.launch,"gimp"); assert(g.icon.indexOf("image://icon/gimp")==0);
console.log("ok");
