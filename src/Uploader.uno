using Uno;
using Uno.UX;
using Fuse;
using Fuse.Scripting;
using Fuse.Reactive;
using Uno.Threading;
using Uno.Net.Http;
using Uno.IO;
using Uno.Text;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;

[UXGlobalModule]
[extern(iOS) Require("Source.Declaration", "#include \"STHTTPRequest.h\"")]
public class Uploader : NativeModule
{
    static readonly Uploader _instance;
    static NativeEvent _nativeStartingEvent;
    static NativeEvent _nativeEventProgress;
    static NativeEvent _nativeEventProgressCompleted;
    public Uploader()
    {
        if (_instance != null) return;
        Uno.UX.Resource.SetGlobalKey(_instance = this, "Uploader");
      
        AddMember(new NativePromise<string, string>("send",         (FutureFactory<string>)send, null));
        AddMember(new NativePromise<string, string>("sendMultiple", (FutureFactory<string>)sendMultiple, null));

        _nativeEventProgress          = new NativeEvent("progressChanged"); 
        _nativeEventProgressCompleted = new NativeEvent("requestCompleted"); 
        _nativeStartingEvent          = new NativeEvent("starting"); 

        AddMember(_nativeEventProgress);
        AddMember(_nativeEventProgressCompleted);
        AddMember(_nativeStartingEvent);
    }
    
    static Future<string> send(object[] args)
    {

        var path = (string)args[0];
        
        var uri = (string)args[1];

        var my_params = args[2] as Fuse.IObject;

        if defined(iOS)
        {
            debug_log "[{\"FilePath\":\""+path+"\"}]";
            sendRequestImpl(uri,"[{\"FilePath\":\""+path+"\"}]",Fuse.Json.Stringify(my_params));
            p = new Promise<string>();
            return p;
        }

        var fileName = Path.GetFileName(path);

        var fileExt = Path.GetExtension(path).ToLower();


        var imageData = Uno.IO.File.ReadAllBytes(path);

        var fileType = "image/png";
        if (fileExt == ".jpg" || fileExt == ".jpeg")
        {
          fileType = "image/jpeg";
        }
        else if (fileExt == ".gif")
        {
          fileType = "image/gif";
        }
        else if (fileExt == ".mp4")
        {
          fileType = "video/mp4";
        }

        Dictionary<string, string> headers = new Dictionary<string, string>();

        Dictionary<string, object> postParameters = new Dictionary<string, object>();
        var keys = my_params.Keys;

       for (int i=0; i < keys.Length; ++i)
        {
            var p = keys[i];
            var o = my_params[p];


            postParameters.Add(p, o);
        }

        postParameters.Add("filename", fileName);
        postParameters.Add("fileformat", fileExt);
        postParameters.Add("file", new FormUpload.FileParameter(imageData, fileName, fileType));

        byte[] formData = null;
        var request = FormUpload.MultipartFormDataPost(uri, "POST", headers, postParameters, out formData);



        var promise = new Promise<string>();
        new ResultClosure(promise,_nativeEventProgress,_nativeEventProgressCompleted, request);

        request.SendAsync(formData);

        return promise;
    }

    static Promise<string> p {
            get; set;
    }

    public static void Picked (string body) {
        p.Resolve(body);
    }

    public static void Cancelled (string error) {
        p.Reject(new Exception(error));
    }
  
    static Future<string> sendMultiple(object[] args)
    {
        
        var path = args[0] as Fuse.Scripting.Array;

        var uri = (string)args[1];

        var my_params = args[2] as Fuse.IObject;

        if defined(iOS)
        {
            sendRequestImpl(uri,Fuse.Json.Stringify(path),Fuse.Json.Stringify(my_params));
            p = new Promise<string>();
            return p;
        }
        Dictionary<string, string> headers = new Dictionary<string, string>();

        Dictionary<string, object> postParameters = new Dictionary<string, object>();
        var keys = my_params.Keys;

       for (int i=0; i < keys.Length; ++i)
        {
            var p = keys[i];
            var o = my_params[p];


            postParameters.Add(p, o);
        }


       for (int i=0; i < path.Length; ++i)
        {



            var obj = path[i] as Fuse.Scripting.Object;
            var fileName = Path.GetFileName(obj["FilePath"]+"");

            var fileExt = Path.GetExtension(obj["FilePath"]+"").ToLower();


            var imageData = Uno.IO.File.ReadAllBytes(obj["FilePath"]+"");

            var fileType = "image/png";
            if (fileExt == ".jpg" || fileExt == ".jpeg")
            {
              fileType = "image/jpeg";
            }
            else if (fileExt == ".gif")
            {
              fileType = "image/gif";
            }
            else if (fileExt == ".mp4")
            {
              fileType = "video/mp4";
            }


            postParameters.Add("filename["+i+"]", fileName);
            postParameters.Add("fileformat["+i+"]", fileExt);
            postParameters.Add("file["+i+"]", new FormUpload.FileParameter(imageData, fileName, fileType));

        }

        byte[] formData = null;
        var request = FormUpload.MultipartFormDataPost(uri, "POST", headers, postParameters, out formData);



        var promise = new Promise<string>();
        new ResultClosure(promise,_nativeEventProgress,_nativeEventProgressCompleted, request);

        request.SendAsync(formData);

        return promise;
    }

    [Require("Cocoapods.Podfile.Pre", " use_frameworks!")]
    [Require("Cocoapods.Podfile.Target", "pod 'STHTTPRequest'")]
    [Require("Entity","OnCompleted()")]
    [Require("Entity","OnProgress(int,int)")]
    [Foreign(Language.ObjC)]
    public static extern(iOS) void sendRequestImpl(string URL,string files,string body)
    @{

        NSError *jsonError;

        STHTTPRequest *r = [STHTTPRequest requestWithURLString:URL];
        r.timeoutSeconds = 360000;
        
        NSData *postObjectData = [body dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *postJson = [NSJSONSerialization JSONObjectWithData:postObjectData
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        r.POSTDictionary = postJson;
        
        r.encodePOSTDictionary = NO;

        [r setHeaderWithName:@"content-type" value:@"application/json; charset=utf-8"];


        NSData *filesObjectData = [files dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *filesJson = [NSJSONSerialization JSONObjectWithData:filesObjectData
                                                                 options:NSJSONReadingMutableContainers
                                                                   error:&jsonError];
        NSUInteger i = 0;
        NSInteger filesCount = [filesJson count];
      
        if(filesCount > 1)
        {
            for (id key in filesJson) 
            {
                for(id keyValue in key) 
                {
                    NSString *currentValue = [key objectForKey:keyValue];
                    [r addFileToUpload:currentValue parameterName:[NSString stringWithFormat:@"file[%lu]", (unsigned long)i]];
                    i=i+1;
                }
            }
        }
        else
        {
            for (id key in filesJson) 
            {
                for(id keyValue in key) 
                {
                    NSString *currentValue = [key objectForKey:keyValue];
                    [r addFileToUpload:currentValue parameterName:@"file"];
                }
            }
        }


        r.completionBlock = ^(NSDictionary *headers, NSString *body) {
            @{Picked(string):Call(body)};
            @{OnCompleted():Call()};
        };
        
        r.errorBlock = ^(NSError *error) {
            @{Cancelled(string):Call([error localizedDescription])};
        };
        
        r.uploadProgressBlock = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            @{OnProgress(int,int):Call((int)totalBytesWritten,(int)totalBytesExpectedToWrite)};
        };
        
        r.downloadProgressBlock = ^(NSData *dataJustReceived,
                                    int64_t totalBytesReceived,
                                    int64_t totalBytesExpectedToReceive) {
            if(totalBytesReceived == totalBytesExpectedToReceive)
            {
                @{OnCompleted():Call()};
            }
        };
        
        [r startAsynchronous];
        @{OnStarting():Call()};
    @}

    public static void OnCompleted()
    {
        _nativeEventProgressCompleted.RaiseAsync();
    }

    public static void OnStarting()
    {
        _nativeStartingEvent.RaiseAsync();
    }

    public static void OnProgress(int current,int total)
    {
        var ret = new object[2];
        ret[0] = current;
        ret[1] = total;
        debug_log "current = "+current;
        debug_log "total   = "+total;
        _nativeEventProgress.RaiseAsync(ret);
    }

    class ResultClosure
    {
        Promise<string> _promise;

        public ResultClosure(Promise<string> promise,NativeEvent _nativeEventProgress,NativeEvent _nativeEventProgressCompleted, HttpMessageHandlerRequest request)
        {
            debug_log "Before 1";
           
            _promise = promise;

            request.Done += Done;
            request.Aborted += Aborted;
            request.Error += Error;
            request.Timeout += Timeout;
            request.Progress += Progress;

            debug_log "After 1";

        }

        void Done(HttpMessageHandlerRequest r) {
            _nativeEventProgressCompleted.RaiseAsync();
            _promise.Resolve(r.GetResponseContentString());
        }
        void Progress(HttpMessageHandlerRequest r,int current, int total, bool hastotal) {

          debug_log "Progressssss";
          var ret = new object[2];
          ret[0] = current;
          ret[1] = total;
          debug_log "current = "+current;
          debug_log "total   = "+total;
          _nativeEventProgress.RaiseAsync(ret);
        }

        void Error(HttpMessageHandlerRequest r, string message) { _promise.Reject(new Exception(message)); }

        void Aborted(HttpMessageHandlerRequest r) { _promise.Reject(new Exception("Aborted")); }

        void Timeout(HttpMessageHandlerRequest r) { _promise.Reject(new Exception("Timeout")); }
    }
}

// Implements multipart/form-data POST in C# http://www.ietf.org/rfc/rfc2388.txt
// http://www.briangrinstead.com/blog/multipart-form-post-in-c
// Following code is a modification from the code posted at the above URL.
public static class FormUpload
{
    private static readonly Encoding encoding = Encoding.UTF8;
    public static HttpMessageHandlerRequest MultipartFormDataPost(string postUrl, string postMethod, Dictionary<string,string> headers, Dictionary<string, object> postParameters, out byte[] formData)
    {
        string formDataBoundary = String.Format("----------{0:N}", DateTime.UtcNow.Ticks.ToString());
        string contentType = "multipart/form-data; boundary=" + formDataBoundary;

        formData = GetMultipartFormData(postParameters, formDataBoundary);

        return PostForm(postUrl, postMethod, contentType, headers, formData);
    }
    private static HttpMessageHandlerRequest PostForm(string postUrl, string postMethod, string contentType, Dictionary<string,string> headers, byte[] formData)
    {
        var client = new HttpMessageHandler();
        HttpMessageHandlerRequest request = client.CreateRequest(postMethod, postUrl);
        if (request == null)
        {

          return request;
        }

        foreach (var header in headers) {
          request.SetHeader(header.Key, header.Value);
        }

        request.SetHeader("Content-Type", contentType);
        request.SetHeader("Content-Length", formData.Length.ToString());

        return request;
    }

    private static byte[] GetMultipartFormData(Dictionary<string, object> postParameters, string boundary)
    {
        Stream formDataStream = new Uno.IO.MemoryStream();
        bool needsCLRF = false;

        foreach (var param in postParameters)
        {
            if (needsCLRF)
            {
                var bytes = Utf8.GetBytes("\r\n");
                formDataStream.Write(bytes, 0, bytes.Length);
            }

            needsCLRF = true;

            if (param.Value is FileParameter)
            {
                FileParameter fileToUpload = (FileParameter)param.Value;

                string header = string.Format("--{0}\r\nContent-Disposition: form-data; name=\"{1}\"; filename=\"{2}\"\r\nContent-Type: {3}\r\n\r\n",
                    boundary,
                    param.Key,
                    fileToUpload.FileName ?? param.Key,
                    fileToUpload.ContentType ?? "application/octet-stream");
                    var bytes = Utf8.GetBytes(header);

                formDataStream.Write(bytes, 0, bytes.Length);

                formDataStream.Write(fileToUpload.File, 0, fileToUpload.File.Length);
            }
            else
            {
                string postData = string.Format("--{0}\r\nContent-Disposition: form-data; name=\"{1}\"\r\n\r\n{2}",
                    boundary,
                    param.Key,
                    param.Value ?? "");
                    var bytes = Utf8.GetBytes(postData);
                formDataStream.Write(bytes, 0, bytes.Length);
            }
        }

        // Add the end of the request.  Start with a newline
        string footer = "\r\n--" + boundary + "--\r\n";
        var fbytes = Utf8.GetBytes(footer);
        formDataStream.Write(fbytes, 0, fbytes.Length);

        // Dump the Stream into a byte[]
        formDataStream.Position = 0;
        byte[] formData = new byte[(int)formDataStream.Length];
        formDataStream.Read(formData, 0, formData.Length);
        formDataStream.Close();

        return formData;
    }

    public class FileParameter
    {
        public byte[] File { get; set; }
        public string FileName { get; set; }
        public string ContentType { get; set; }
        public FileParameter(byte[] file) : this(file, null) { }
        public FileParameter(byte[] file, string filename) : this(file, filename, null) { }
        public FileParameter(byte[] file, string filename, string contenttype)
        {
            File = file;
            FileName = filename;
            ContentType = contenttype;
        }
    }
}