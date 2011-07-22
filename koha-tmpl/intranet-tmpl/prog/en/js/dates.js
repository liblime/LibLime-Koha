// Declaring valid date character, minimum year and maximum year
var dtCh= "-";
var minYear=2000;
var maxYear=2100;

function isInteger(s){
	var i;
    for (i = 0; i < s.length; i++){   
        // Check that current character is number.
        var c = s.charAt(i);
        if (((c < "0") || (c > "9"))) return false;
    }
    // All characters are numbers.
    return true;
}

function stripCharsInBag(s, bag){
	var i;
    var returnString = "";
    // Search through string's characters one by one.
    // If character is not in bag, append to returnString.
    for (i = 0; i < s.length; i++){   
        var c = s.charAt(i);
        if (bag.indexOf(c) == -1) returnString += c;
    }
    return returnString;
}

function daysInFebruary (year){
	// February has 29 days in any year evenly divisible by four,
    // EXCEPT for centurial years which are not also divisible by 400.
    return (((year % 4 == 0) && ( (!(year % 100 == 0)) || (year % 400 == 0))) ? 29 : 28 );
}
function DaysArray(n) {
	for (var i = 1; i <= n; i++) {
		this[i] = 31
		if (i==4 || i==6 || i==9 || i==11) {this[i] = 30}
		if (i==2) {this[i] = 29}
   } 
   return this
}

function isDate(dtStr){
	var daysInMonth = DaysArray(12)
	var pos1=dtStr.indexOf(dtCh)
	var pos2=dtStr.indexOf(dtCh,pos1+1)
	var strMonth=dtStr.substring(0,pos1)
	var strDay=dtStr.substring(pos1+1,pos2)
	var strYear=dtStr.substring(pos2+1)
	strYr=strYear
	//if (strDay.charAt(0)=="0" && strDay.length>1) strDay=strDay.substring(1)
	//if (strMonth.charAt(0)=="0" && strMonth.length>1) strMonth=strMonth.substring(1)
	for (var i = 1; i <= 3; i++) {
		if (strYr.charAt(0)=="0" && strYr.length>1) strYr=strYr.substring(1)
	}
	month=parseInt(strMonth)
	day=parseInt(strDay)
	year=parseInt(strYr)
	if (pos1==-1 || pos2==-1){
		alert("The date format should be : mm-dd-yyyy")
		return false
	}
	if (strMonth.length<2 || strMonth<1 || month>12){
		alert("Please enter a valid month")
		return false
	}
	if (strDay.length<2 || day<1 || day>31 || (month==2 && day>daysInFebruary(year)) || day > daysInMonth[month]){
		alert("Please enter a valid day")
		return false
	}
	if (strYear.length != 4 || year==0 || year<minYear || year>maxYear){
		alert("Please enter a valid 4 digit year between "+minYear+" and "+maxYear)
		return false
	}
	if (dtStr.indexOf(dtCh,pos2+1)!=-1 || isInteger(stripCharsInBag(dtStr, dtCh))==false){
		alert("Please enter a valid date")
		return false
	}
return true
}

function ValidateForm(){
	var dt=document.frmSample.txtDate
	if (isDate(dt.value)==false){
		dt.focus()
		return false
	}
    return true
 }

// args: date in UI format, dateformat syspref, database type
function dformat2db(d,dformat,mydb) {
   // current db format is mysql: YYYY-MM-DD
   if(!mydb) { mydb = 'mysql' }
   if(d) {
      var parts=d.split('/');
      if (mydb=='mysql') {
         if      (dformat=='us')  { return [parts[2],parts[0],parts[1]].join('-') }
         else if (dformat=='iso') { return [parts[0],parts[1],parts[2]].join('-') }
         else                     { return [parts[2],parts[1],parts[0]].join('-') }
      }
      else {
         alert('Error: unsupported date and/or database type');
      }
   }
}

// currently supports only mysql timestamp
function ts2date(ts,dformat) {
   if (ts) {
      var regex=/^([0-9]{2,4})-([0-1][0-9])-([0-3][0-9])\s*(?:([0-2][0-9]):([0-5][0-9]):([0-5][0-9]))?$/;
      var parts=ts.replace(regex,"$1 $2 $3 $4 $5 $6").split(' ');
      if      (dformat=='us')  { return [parts[1],parts[2],parts[0]].join('/') }
      else if (dformat=='iso') { return [parts[0],parts[1],parts[2]].join('/') }
      else                     { return [parts[2],parts[1],parts[0]].join('/') }
   }
   return '';
//   var d = new Date(parts[0],parts[1]-1,parts[2],parts[3],parts[4],parts[5]);
}

