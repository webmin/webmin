Xinha=window.opener.Xinha;
HTMLArea=window.opener.Xinha;
function getAbsolutePos(el){
var r={x:el.offsetLeft,y:el.offsetTop};
if(el.offsetParent){
var _3=getAbsolutePos(el.offsetParent);
r.x+=_3.x;
r.y+=_3.y;
}
return r;
}
function comboSelectValue(c,_5){
var _6=c.getElementsByTagName("option");
for(var i=_6.length;--i>=0;){
var op=_6[i];
op.selected=(op.value==_5);
}
c.value=_5;
}
function __dlg_onclose(){
opener.Dialog._return(null);
}
function __dlg_init(_9,_a){
__xinha_dlg_init(_a);
}
function __xinha_dlg_init(_b){
if(window.__dlg_init_done){
return true;
}
if(window.opener._editor_skin!=""){
var _c=document.getElementsByTagName("head")[0];
var _d=document.createElement("link");
_d.type="text/css";
_d.href=window.opener._editor_url+"skins/"+window.opener._editor_skin+"/skin.css";
_d.rel="stylesheet";
_c.appendChild(_d);
}
window.dialogArguments=opener.Dialog._arguments;
var _e=document.body;
if(!_b){
var _f=Xinha.viewportSize(window);
_b={width:_f.x,height:_e.scrollHeight};
}
window.resizeTo(_b.width,_b.height);
var _f=Xinha.viewportSize(window);
window.resizeBy(0,_e.scrollHeight-_f.y);
if(_b.top&&_b.left){
window.moveTo(_b.left,_b.top);
}else{
if(!Xinha.is_ie){
var x=opener.screenX+(opener.outerWidth-_b.width)/2;
var y=opener.screenY+(opener.outerHeight-_b.height)/2;
}else{
var x=(self.screen.availWidth-_b.width)/2;
var y=(self.screen.availHeight-_b.height)/2;
}
window.moveTo(x,y);
}
Xinha.addDom0Event(document.body,"keypress",__dlg_close_on_esc);
window.__dlg_init_done=true;
}
function __dlg_translate(_12){
var _13=["input","select","legend","span","option","td","th","button","div","label","a","img"];
for(var _14=0;_14<_13.length;++_14){
var _15=document.getElementsByTagName(_13[_14]);
for(var i=_15.length;--i>=0;){
var _17=_15[i];
if(_17.firstChild&&_17.firstChild.data){
var txt=Xinha._lc(_17.firstChild.data,_12);
if(txt){
_17.firstChild.data=txt;
}
}
if(_17.title){
var txt=Xinha._lc(_17.title,_12);
if(txt){
_17.title=txt;
}
}
if(_17.tagName.toLowerCase()=="input"&&(/^(button|submit|reset)$/i.test(_17.type))){
var txt=Xinha._lc(_17.value,_12);
if(txt){
_17.value=txt;
}
}
}
}
document.title=Xinha._lc(document.title,_12);
}
function __dlg_close(val){
opener.Dialog._return(val);
window.close();
}
function __dlg_close_on_esc(ev){
ev||(ev=window.event);
if(ev.keyCode==27){
__dlg_close(null);
return false;
}
return true;
}

