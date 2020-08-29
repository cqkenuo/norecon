#!/usr/bin/env hy

(require [hy.extra.anaphoric [*]]
         [helpers [*]]
         )

(import os
        logging
        sys
        re
        json
        argparse

        [datetime [datetime]]
        [helpers [*]]
        [project [*]]
        [shutil [copy]]
        [jinja2 [Environment
                 FileSystemLoader
                 PackageLoader]]
        [glob [glob]]
        [iploc [get-location]]
        )

(setv curr-dir (try --file--
                    (os.path.dirname --file--)
                    (except [NameError]
                      (os.getcwd))))

(setv env (Environment :loader (FileSystemLoader (os.path.join curr-dir "templates"))
                       :trim-blocks True
                       :lstrip-blocks True))

(defn render->file
  [template-name data filepath]
  (with [w (open filepath "w")]
    (-> (env.get-template template-name)
        (.render data)
        (w.write))))

(defn render-project-notes
  [project-dir item-dir template get-arg-fn]
  "`get-arg-fn` 生成传递给模板参数的函数:接受参数为target(当前要生成的项目名)"
  (setv save-path (os.path.join project-dir "notes" item-dir))
  (os.makedirs save-path :exist-ok True)
  (for [f (glob (os.path.join project-dir item-dir "*.json"))]
    (setv target (-> (os.path.basename f)
                     (os.path.splitext)
                     first))
    (render->file template (get-arg-fn target)
                  (os.path.join save-path f"{target}.md"))))

(defn render-whois
  [project-dir]
  (render-project-notes :project-dir project-dir
                        :item-dir "whois"
                        :template "whois.md"
                        :get-arg-fn (fn [target]
                                      {"data" (read-whois target project-dir)
                                       "target" target})))

(defn render-domain
  [project-dir]
  (render-project-notes :project-dir project-dir
                        :item-dir "domain"
                        :template "domain.md"
                        :get-arg-fn (fn [target]
                                      {"data" (read-domain target project-dir)
                                       "target" target})))

(defn gen-screen-info
  [target project-dir]
  (setv resource-dir (os.path.join project-dir "notes" "resources"))
  (os.makedirs resource-dir :exist-ok True)
  (some-> (read-screen-session target project-dir)
          (.get "pages")
          (.items)
          (as-> $
                (lfor [k d] $
                      :do (do
                            (setv (of d "target") k)
                            (as-> (.get d "screenshotPath") spath
                                  (when spath
                                    (-> (copy (os.path.join project-dir "screen" spath)
                                              resource-dir)
                                        (os.path.relpath (os.path.join project-dir "notes" "ip"))
                                        (->> (setv (of d "screenshotPath")))))))
                      d))))

(defn render-ip
  [project-dir]
  (render-project-notes :project-dir project-dir
                        :item-dir "ip"
                        :template "ip.md"
                        :get-arg-fn (fn [target]
                                      {"data" (read-ip target project-dir)
                                       "screen" (gen-screen-info target project-dir)
                                       "location" (get-location target)
                                       "target" target})))

(defn render-record
  [project-dir]
  (render-project-notes :project-dir project-dir
                        :item-dir "record"
                        :template "record.md"
                        :get-arg-fn (fn [target]
                                      {"data" (read-record target project-dir)
                                       "screen" (gen-screen-info target project-dir)
                                       "target" target})))
