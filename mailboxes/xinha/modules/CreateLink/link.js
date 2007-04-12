CreateLink._pluginInfo={name:"CreateLink",origin:"Xinha Core",version:"$LastChangedRevision: 694 $".replace(/^[^:]*: (.*) \$$/,"$1"),developer:"The Xinha Core Developer Team",developer_url:"$HeadURL: http://svn.xinha.python-hosting.com/tags/0.92beta/modules/CreateLink/link.js $".replace(/^[^:]*: (.*) \$$/,"$1"),sponsor:"",sponsor_url:"",license:"htmlArea"};
function CreateLink(_1){
}
Xinha.prototype._createLink=function(_2){
var _3=this;
var _4=null;
if(typeof _2=="undefined"){
_2=this.getParentElement();
if(_2){
while(_2&&!/^a$/i.test(_2.tagName)){
_2=_2.parentNode;
}
}
}
if(!_2){
var _5=_3.getSelection();
var _6=_3.createRange(_5);
var _7=0;
if(Xinha.is_ie){
if(_5.type=="Control"){
_7=_6.length;
}else{
_7=_6.compareEndPoints("StartToEnd",_6);
}
}else{
_7=_6.compareBoundaryPoints(_6.START_TO_END,_6);
}
if(_7===0){
alert(Xinha._lc("You need to select some text before creating a link"));
return;
}
_4={f_href:"",f_title:"",f_target:"",f_usetarget:_3.config.makeLinkShowsTarget};
}else{
_4={f_href:Xinha.is_ie?_3.stripBaseURL(_2.href):_2.getAttribute("href"),f_title:_2.title,f_target:_2.target,f_usetarget:_3.config.makeLinkShowsTarget};
}
Dialog(_3.config.URIs.link,function(_8){
if(!_8){
return false;
}
var a=_2;
if(!a){
try{
var _a=Xinha.uniq("http://www.example.com/Link");
_3._doc.execCommand("createlink",false,_a);
var _b=_3._doc.getElementsByTagName("a");
for(var i=0;i<_b.length;i++){
var _d=_b[i];
if(_d.href==_a){
if(!a){
a=_d;
}
_d.href=_8.f_href;
if(_8.f_target){
_d.target=_8.f_target;
}
if(_8.f_title){
_d.title=_8.f_title;
}
}
}
}
catch(ex){
}
}else{
var _e=_8.f_href.trim();
_3.selectNodeContents(a);
if(_e===""){
_3._doc.execCommand("unlink",false,null);
_3.updateToolbar();
return false;
}else{
a.href=_e;
}
}
if(!(a&&a.tagName.toLowerCase()=="a")){
return false;
}
a.target=_8.f_target.trim();
a.title=_8.f_title.trim();
_3.selectNodeContents(a);
_3.updateToolbar();
},_4);
};

