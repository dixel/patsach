(ns chat.core
  (:require [aleph.tcp :as tcp]
            [manifold.stream :as stream]
            [byte-streams :as bs]
            [clojure.core.async :as a]
            [clojure.string :as str]))

(def message-buffer (a/chan))

(def message-mult (a/mult message-buffer))

(defn random-name []
  (let [name-length (+ 3 (rand-int 10))]
    (apply str
           (repeatedly name-length #(rand-nth "abcdefghijklmnopqrstuvwxyz")))))

(defn process-connection [s info]
  (let [name (random-name)
        user-in (a/chan
                 10
                 (comp (filter #(< (count %) 140)) ;twitter
                       (filter #(> (count %) 2)) ;not empty
                       (filter #((set (byte-streams/to-string %)) \return));telnet
                       (map #(str name "> " (byte-streams/to-string %)))))
        user-out (a/chan
                  10
                  (filter #(not (str/starts-with? % name))))]
    (stream/put! s (str "serv> hi! now your name is " name "\r\n"))
    (a/tap message-mult user-out false)
    (a/pipe user-in message-buffer false)
    (stream/connect (stream/->source user-out) s)
    (stream/connect s (stream/->sink user-in))))

(defn -main [& _]
  (tcp/start-server process-connection {:port 1234}))
