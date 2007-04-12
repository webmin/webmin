InsertImage._pluginInfo={name:"InsertImage",origin:"Xinha Core",version:"$LastChangedRevision: 733 $".replace(/^[^:]*: (.*) \$$/,"$1"),developer:"The Xinha Core Developer Team",developer_url:"$HeadURL: http://svn.xinha.python-hosting.com/tags/0.92beta/modules/InsertImage/insert_image.js $".replace(/^[^:]*: (.*) \$$/,"$1"),sponsor:"",sponsor_url:"",license:"htmlArea"};
function InsertImage(_1){
}
Xinha.prototype._insertImage=function(_2){
var _3=this;
var _4;
if(typeof _2=="undefined"){
_2=this.getParentElement();
if(_2&&_2.tagName.toLowerCase()!="img"){
_2=null;
}
}
var _5;
if(typeof _3.config.baseHref!="undefined"&&_3.config.baseHref!==null){
_5=_3.config.baseHref;
}else{
var _6=window.location.toString().split("/");
_6.pop();
_5=_6.join("/");
}
if(_2){
_4={f_base:_5,f_url:Xinha.is_ie?_3.stripBaseURL(_2.src):_2.getAttribute("src"),f_alt:_2.alt,f_border:_2.border,f_align:_2.align,f_vert:(_2.vspace!=-1?_2.vspace:""),f_horiz:(_2.hspace!=-1?_2.hspace:""),f_width:_2.width,f_height:_2.height};
}else{
_4={f_base:_5,f_url:""};
}
Dialog(_3.config.URIs.insert_image,function(_7){
if(!_7){
return false;
}
var _8=_2;
if(!_8){
if(Xinha.is_ie){
var _9=_3.getSelection();
var _a=_3.createRange(_9);
_3._doc.execCommand("insertimage",false,_7.f_url);
_8=_a.parentElement();
if(_8.tagName.toLowerCase()!="img"){
_8=_8.previousSibling;
}
}else{
_8=document.createElement("img");
_8.src=_7.f_url;
_3.insertNodeAtSelection(_8);
if(!_8.tagName){
_8=_a.startContainer.firstChild;
}
}
}else{
_8.src=_7.f_url;
}
for(var _b in _7){
var _c=_7[_b];
switch(_b){
case "f_alt":
if(_c){
_8.alt=_c;
}else{
_8.removeAttribute("alt");
}
break;
case "f_border":
if(_c){
_8.border=parseInt(_c||"0");
}else{
_8.removeAttribute("border");
}
break;
case "f_align":
if(_c){
_8.align=_c;
}else{
_8.removeAttribute("align");
}
break;
case "f_vert":
if(_c){
_8.vspace=parseInt(_c||"0");
}else{
_8.removeAttribute("vspace");
}
break;
case "f_horiz":
if(_c){
_8.hspace=parseInt(_c||"0");
}else{
_8.removeAttribute("hspace");
}
break;
case "f_width":
if(_c){
_8.width=parseInt(_c||"0");
}else{
_8.removeAttribute("width");
}
break;
case "f_height":
if(_c){
_8.height=parseInt(_c||"0");
}else{
_8.removeAttribute("height");
}
break;
}
}
},_4);
};

