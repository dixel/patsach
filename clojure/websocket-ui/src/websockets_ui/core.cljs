(ns websockets-ui.core
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [reagent.core :as reagent]
            [cljs.core.async :as a]))

(defonce state (reagent/atom {:text ""}))

(defn handle-typing [input]
  (swap! state #(assoc % :text (-> input
                                      .-target
                                      .-value))))

(defn random-name []
  (let [name-length (+ 3 (rand-int 10))]
    (apply str
           (repeatedly name-length #(rand-nth "abcdefghijklmnopqrstuvwxyz")))))

(def username (random-name))

(defn create-ws []
  (let [ws (js/WebSocket. "ws://localhost:8181")]
    (set! (.-onmessage ws)
          (fn [message]
            (swap! state (fn [s]
                           (assoc s :history
                                  (-> (:history s)
                                      (conj [:div [:code (.-data message)]])
                                      (#(drop-last (- (count %) 25) %))))))))
    (swap! state #(assoc % :ws ws))
    (set! (.-onopen ws)
          #(.send ws username))))

(defn home-page []
  [:div [:div [:h2 "awesome chat"]]
   [:div [:p (str username " is typing: " (:text @state))]]
   [:input {:type "text"
            :value (:text @state "")
            :on-change handle-typing
            :on-key-down (fn [key]
                           (when (= (.-keyCode key) 13)
                             (do
                               (.send (:ws @state) (str "<" username "> "
                                                        (:text @state)))
                               (swap! state #(assoc % :text "")))))}]
   [:div (:history @state)]])

(defn mount-root []
  (reagent/render [home-page] (.-body js/document)))

(defn init! []
  (create-ws)
  (mount-root))
