function Dialog(_1,_2,_3){
if(typeof _3=="undefined"){
_3=window;
}
Dialog._geckoOpenModal(_1,_2,_3);
}
Dialog._parentEvent=function(ev){
setTimeout(function(){
if(Dialog._modal&&!Dialog._modal.closed){
Dialog._modal.focus();
}
},50);
try{
if(Dialog._modal&&!Dialog._modal.closed){
Xinha._stopEvent(ev);
}
}
catch(e){
}
};
Dialog._return=null;
Dialog._modal=null;
Dialog._arguments=null;
Dialog._geckoOpenModal=function(_5,_6,_7){
var _8=window.open(_5,"hadialog","toolbar=no,menubar=no,personalbar=no,width=10,height=10,"+"scrollbars=no,resizable=yes,modal=yes,dependable=yes");
Dialog._modal=_8;
Dialog._arguments=_7;
function capwin(w){
Xinha._addEvent(w,"click",Dialog._parentEvent);
Xinha._addEvent(w,"mousedown",Dialog._parentEvent);
Xinha._addEvent(w,"focus",Dialog._parentEvent);
}
function relwin(w){
Xinha._removeEvent(w,"click",Dialog._parentEvent);
Xinha._removeEvent(w,"mousedown",Dialog._parentEvent);
Xinha._removeEvent(w,"focus",Dialog._parentEvent);
}
capwin(window);
for(var i=0;i<window.frames.length;i++){
try{
capwin(window.frames[i]);
}
catch(e){
}
}
Dialog._return=function(_c){
if(_c&&_6){
_6(_c);
}
relwin(window);
for(var i=0;i<window.frames.length;i++){
try{
relwin(window.frames[i]);
}
catch(e){
}
}
Dialog._modal=null;
};
Dialog._modal.focus();
};

