var num=1;
if(window.parent&&window.parent!=window){
var f=window.parent.menu.document.forms[0];
_editor_lang=f.lang[f.lang.selectedIndex].value;
_editor_skin=f.skin[f.skin.selectedIndex].value;
num=parseInt(f.num.value);
if(isNaN(num)){
num=1;
f.num.value=1;
}
xinha_plugins=[];
for(var x=0;x<f.plugins.length;x++){
if(f.plugins[x].checked){
xinha_plugins.push(f.plugins[x].value);
}
}
}
xinha_editors=[];
for(var x=0;x<num;x++){
var ta="myTextarea"+x;
xinha_editors.push(ta);
}
xinha_config=function(){
var _1=new HTMLArea.Config();
if(typeof CSS!="undefined"){
_1.pageStyle="@import url(custom.css);";
}
if(typeof Stylist!="undefined"){
_1.stylistLoadStylesheet(document.location.href.replace(/[^\/]*\.html/,"stylist.css"));
_1.stylistLoadStyles("p.red_text { color:red }");
_1.stylistLoadStyles("p.pink_text { color:pink }",{"p.pink_text":"Pretty Pink"});
}
if(typeof DynamicCSS!="undefined"){
_1.pageStyle="@import url(dynamic.css);";
}
if(typeof InsertWords!="undefined"){
var _2=new Object();
var _3=new Object();
_2["-- Dropdown Label --"]="";
_2["onekey"]="onevalue";
_2["twokey"]="twovalue";
_2["threekey"]="threevalue";
_3["-- Insert Keyword --"]="";
_3["Username"]="%user%";
_3["Last login date"]="%last_login%";
_1.InsertWords={combos:[{options:_2,context:"body"},{options:_3,context:"li"}]};
}
if(typeof ListType!="undefined"){
if(window.parent&&window.parent!=window){
var f=window.parent.menu.document.forms[0];
_1.ListType.mode=f.elements["ListTypeMode"].options[f.elements["ListTypeMode"].selectedIndex].value;
}
}
if(typeof CharacterMap!="undefined"){
if(window.parent&&window.parent!=window){
var f=window.parent.menu.document.forms[0];
_1.CharacterMap.mode=f.elements["CharacterMapMode"].options[f.elements["CharacterMapMode"].selectedIndex].value;
}
}
if(typeof Filter!="undefined"){
xinha_config.Filters=["Word","Paragraph"];
}
return _1;
};
var f=document.forms[0];
f.innerHTML="";
var lipsum=document.getElementById("lipsum").innerHTML;
for(var x=0;x<num;x++){
var ta="myTextarea"+x;
var div=document.createElement("div");
div.className="area_holder";
var txta=document.createElement("textarea");
txta.id=ta;
txta.name=ta;
txta.value=lipsum;
txta.style.width="100%";
txta.style.height="420px";
div.appendChild(txta);
f.appendChild(div);
}
var submit=document.createElement("input");
submit.type="submit";
submit.id="submit";
submit.value="submit";
f.appendChild(submit);
var _oldSubmitHandler=null;
if(document.forms[0].onsubmit!=null){
_oldSubmitHandler=document.forms[0].onsubmit;
}
function frame_onSubmit(){
alert(document.getElementById("myTextarea0").value);
if(_oldSubmitHandler!=null){
_oldSubmitHandler();
}
}
document.forms[0].onsubmit=frame_onSubmit;

