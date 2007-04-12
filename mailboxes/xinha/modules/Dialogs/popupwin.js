function PopupWin(_1,_2,_3,_4){
this.editor=_1;
this.handler=_3;
var _5=window.open("","__ha_dialog","toolbar=no,menubar=no,personalbar=no,width=600,height=600,left=20,top=40,scrollbars=no,resizable=yes");
this.window=_5;
var _6=_5.document;
this.doc=_6;
var _7=this;
var _8=document.baseURI||document.URL;
if(_8&&_8.match(/(.*)\/([^\/]+)/)){
_8=RegExp.$1+"/";
}
if(typeof _editor_url!="undefined"&&!(/^\//.test(_editor_url))&&!(/http:\/\//.test(_editor_url))){
_8+=_editor_url;
}else{
_8=_editor_url;
}
if(!(/\/$/.test(_8))){
_8+="/";
}
this.baseURL=_8;
_6.open();
var _9="<html><head><title>"+_2+"</title>\n";
_9+="<style type=\"text/css\">@import url("+_editor_url+"Xinha.css);</style>\n";
if(_editor_skin!=""){
_9+="<style type=\"text/css\">@import url("+_editor_url+"skins/"+_editor_skin+"/skin.css);</style>\n";
}
_9+="</head>\n";
_9+="<body class=\"dialog popupwin\" id=\"--HA-body\"></body></html>";
_6.write(_9);
_6.close();
function init2(){
var _a=_6.body;
if(!_a){
setTimeout(init2,25);
return false;
}
_5.title=_2;
_6.documentElement.style.padding="0px";
_6.documentElement.style.margin="0px";
var _b=_6.createElement("div");
_b.className="content";
_7.content=_b;
_a.appendChild(_b);
_7.element=_a;
_4(_7);
_5.focus();
}
init2();
}
PopupWin.prototype.callHandler=function(){
var _c=["input","textarea","select"];
var _d={};
for(var ti=_c.length;--ti>=0;){
var _f=_c[ti];
var els=this.content.getElementsByTagName(_f);
for(var j=0;j<els.length;++j){
var el=els[j];
var val=el.value;
if(el.tagName.toLowerCase()=="input"){
if(el.type=="checkbox"){
val=el.checked;
}
}
_d[el.name]=val;
}
}
this.handler(this,_d);
return false;
};
PopupWin.prototype.close=function(){
this.window.close();
};
PopupWin.prototype.addButtons=function(){
var _14=this;
var div=this.doc.createElement("div");
this.content.appendChild(div);
div.id="buttons";
div.className="buttons";
for(var i=0;i<arguments.length;++i){
var btn=arguments[i];
var _18=this.doc.createElement("button");
div.appendChild(_18);
_18.innerHTML=HTMLArea._lc(btn,"HTMLArea");
switch(btn.toLowerCase()){
case "ok":
HTMLArea.addDom0Event(_18,"click",function(){
_14.callHandler();
_14.close();
return false;
});
break;
case "cancel":
HTMLArea.addDom0Event(_18,"click",function(){
_14.close();
return false;
});
break;
}
}
};
PopupWin.prototype.showAtElement=function(){
var _19=this;
setTimeout(function(){
var w=_19.content.offsetWidth+4;
var h=_19.content.offsetHeight+4;
var el=_19.content;
var s=el.style;
s.position="absolute";
s.left=parseInt((w-el.offsetWidth)/2,10)+"px";
s.top=parseInt((h-el.offsetHeight)/2,10)+"px";
if(HTMLArea.is_gecko){
_19.window.innerWidth=w;
_19.window.innerHeight=h;
}else{
_19.window.resizeTo(w+8,h+70);
}
},25);
};

