/**
 *  Plugin ftpupload
 *
 *  Copyright (c) 2013 Gokce Taskan
 *  
**/
 
/* Get local ref to global PhoneGap/Cordova/cordova object for exec function.
- This increases the compatibility of the plugin. */
var cordovaRef = window.PhoneGap || window.Cordova || window.cordova; // old to new fallbacks

function FtpUpload() {
    this.resultCallback = null; // Function
}

FtpUpload.prototype.sendFile = function(successCallback, failCallback, address, username, password, file) {
    
    var args = {};
    if(address)
        args.address = address;
    if(username)
        args.username = username;
    if(password)
        args.password = password;
    if(file)
        args.file = file;

    return cordovaRef.exec(successCallback, failCallback, "FtpUpload", "sendFile", [args]);
}


cordovaRef.addConstructor(function() {
                       if(!window.plugins) {
                          window.plugins = {};
                       }
                       
                       // shim to work in 1.5 and 1.6
                       if (!window.Cordova) {
                          window.Cordova = cordova;
                       };
                       
                       window.plugins.ftpUpload = new FtpUpload();
                          
});