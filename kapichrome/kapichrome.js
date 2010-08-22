
//Get url parameters (www.netlobo.com/url_query_string_javascript.html)
function gup( name )
{
  name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
  var regexS = "[\\?&]"+name+"=([^&#]*)";
  var regex = new RegExp( regexS );
  var results = regex.exec( window.location.href );
  if( results == null )
    return "";
  else
    return results[1];
}

/*****/

//Inject my script data into page
var myscriptstuff=document.createElement("script");
myscriptstuff.setAttribute("type","text/javascript");
//Produktionseinstellung nach Zeit - skript zum ausrechnen
var text = "function calcTime(element) {\n"
	+"var prodproh = document.getElementById(\"SPAN_PRODUKT_PRODUZIEREN_PLATZHALTER\").childNodes[0].childNodes[0].childNodes[0].childNodes[0];\n"
	+"prodproh = prodproh.childNodes[2].childNodes[0].childNodes[1].childNodes[0];\n"
	+"prodproh = prodproh.innerHTML.split(\"<br>\");\n"
	+"prodproh = parseFloat(prodproh[prodproh.length-1].split(\" \")[1]);\n"
	+"var arr = element.value.split(\":\");\n"
	+"var prodnum = prodproh * parseFloat(arr[0]);\n"
	+"if(arr.length>1 && arr[1]!=\"\")\n"
	+"	prodnum += prodproh / 60 * parseFloat(arr[1]);\n"
	+"element.parentNode.getElementsByTagName(\"input\")[1].value = Math.round(prodnum);\n"
	+"}\n";
//TODO: Umsatz, gewinn, etc calc für lager
text += "";

myscriptstuff.appendChild(document.createTextNode(text));
document.head.appendChild(myscriptstuff);

prod=document.getElementsByName("a_bestellen[]");
if (prod!=null) {
	for(var i=0; i<prod.length; i++) {
		var textnode = prod[i].parentNode.firstChild;

		var timerinput = document.createElement("input");
		timerinput.setAttribute("type","text");
		timerinput.setAttribute("size","9");
		timerinput.setAttribute("name","timerinput[]");
		timerinput.setAttribute("onkeyup","calcTime(this);");

		prod[i].parentNode.insertBefore(document.createTextNode("Zeit: "),textnode);
		prod[i].parentNode.insertBefore(timerinput,textnode);
		prod[i].parentNode.insertBefore(document.createElement("br"),textnode);
	}
}

if (gup("page")=="lager") {
	// Rechnungsfeld hinzufügen
	var rechnung = document.createElement("div");
	rechnung.setAttribute("id","rechnung");
	rechnung.setAttribute("style","text-align: center;");
	document.getElementById("DIV_WARE_VERSENDEN").insertBefore(rechnung,document.getElementById("DIV_WARE_VERSENDEN").childNodes[2]);
	document.getElementsByName("wbet")[0].setAttribute("onkeyup","javascript:document.getElementById('rechnung').innerHTML='test';");

	// ALLES knöpfe hinzufügen
	var tablerows = document.getElementById("TABLE_MY_PRODUCTS_IN_STOCK").firstChild.childNodes;
	for(var i=1; i<tablerows.length; i++) {
		var numall = parseFloat(tablerows[i].childNodes[0].childNodes[1].nodeValue.split(" ")[0].split(".").join(""));
		var linkall = document.createElement("button");
		linkall.appendChild(document.createTextNode("Alles"));
		linkall.setAttribute("onclick","javascript:this.parentNode.childNodes[0].value='"+numall+"';");
		tablerows[i].childNodes[4].insertBefore(linkall,tablerows[i].childNodes[4].childNodes[1]);
	}
}
