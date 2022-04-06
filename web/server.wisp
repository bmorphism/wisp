(defun main ()
  (defmacro callback (args &rest body)
    `(make-pinned-value
      (fn ,args
        (async (fn ()
                 (with-simple-error-handler ()
                   ,@body))))))

  (defun deno-import (path)
    (await
     (js-call *wisp* "import" path)))

  (defvar <server>
    (deno-import
     "https://deno.land/std@0.133.0/http/server.ts"))

  (defun serve (port handler)
    (await
     (returning
         (js-call <server> "serve" (callback (req)
                                     (call handler req))
                  (js-object "port" port))
       (print `(http server port ,port)))))

  (defvar <response> (js-get *window* "Response"))

  (defun new (constructor &rest args)
    (apply #'js-new (cons constructor args)))

  (defun response (status headers body)
    (new <response> body
         (js-object "status" status
                    "headers" (apply #'js-object headers))))

  (serve 8000
         (fn (req)
           (progn
             (print `(http request ,(js-get req "url")))
             (response 200 '("content-type" "text/plain")
               "Hello from Wisp!\n")))))

(with-simple-error-handler ()
  (async #'main))
