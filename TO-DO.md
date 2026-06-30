# TO-DO

## Features

- [x] Wir müssen das Tippen der K.O.-Spiele um Verlängerung (VL) und Elfmeterschießen erweitern. Die maximale Punktzahl liegt bei 5, für den Spezialfall Elfmeterschießen bei 6 Punkten. UI & Verhalten: Wenn ein Nutzer nach 90 Min. ein Unentschieden tippt, müssen darunter Scroll-Räder für das Ergebnis n.V. erscheinen. Wichtig: Diese Räder dürfen nicht unter den Score des 90-Minuten-Tipps gedreht werden können. Wenn auch die VL als Unentschieden getippt wird, muss ein Abschnitt für das Elfmeterschießen erscheinen. Hier gibt es keine Ergebnisse mehr, sondern nur zwei exklusive Radio-Buttons für die Teams zur Bestimmung des Siegers. Der Tipp darf nur gespeichert werden, wenn ein finales Siegerteam ausgewählt ist. Verlässt der Nutzer die Seite vorher, wird der halbe Tipp zwischengespeichert, aber in der UI mit einem roten Warnzeichen markiert. In der Listen-Vorschau zeigen wir aus Platzgründen nur den Tipp nach 90 Minuten, in der Detailansicht den kompletten Verlauf. Punktevergabe (Auswertung basiert auf dem realen Spielende): Spiel endet nach 90 Min (max. 5 Punkte): +3 bei richtiger Tendenz, +4 bei korrekter Tordifferenz, +5 bei exaktem Ergebnis. Spiel endet nach VL (max. 5 Punkte): +2 für erkanntes Unentschieden nach 90 Min., +3 für exaktes 90-Min.-Ergebnis. Zusätzlich: +1 für richtige Tendenz n.V., +2 für exaktes Ergebnis n.V. Spiel endet im Elfmeterschießen (max. 6 Punkte): +2 für erkanntes Unentschieden nach 90 Min., +3 für exaktes 90-Min.-Ergebnis. Zusätzlich: +1 für richtige Tendenz n.V. (erneut Unentschieden), +1 für exaktes Ergebnis n.V., +1 für den richtigen Sieger im Elfmeterschießen. Hinweise zur Logik: Bei Unentschieden gibt es nie Punkte für die Tordifferenz. Wenn ein Spieler auf Elfmeterschießen tippt, das reale Spiel aber schon in der VL entschieden wird, wird der Tipp logischerweise nur bis zur VL ausgewertet. Alles darüber hinaus verfällt einfach. Um diese Punktevergabe zu erklären solltest du den Dialog mit den Regeln im Home Tab um einen Absatz für die K.O.-Spiele erweitern.
- [x] In der Liga Tabelle sollte zusätzlich zu den Gesamt Punkten noch eine Spalte mit den reinen Punkten aus den Tipps angezeigt werden, also ohne die Punkt der Team-Picks. Es sollte also eine Spalte geben, die die Gesamt Punkte anzeigt und eine Spalte, die nur die Punkte aus den Tipps anzeigt.
- [x] Es sollten im Falle, dass ein Spieler das Tippen vergisst eine Erinnerung per Push Notification geschickt werden, dass er noch Tipps abgeben kann. Diese Push Notification einmal 12h vor dem Spiel verschickt werden. Außerdem sollte es eine Push Notification geben, die 1 Stunde vor dem Spiel verschickt wird, falls der Spieler noch keine Tipps abgegeben hat. Wenn es mehrere Spiele gibt, die noch nicht getippt wurden, dann sollte die Push Notification nur einmal verschickt werden und nicht für jedes Spiel einzeln. Dazu kannst du ja schauen, ob der Spieler die Spiele des Tages schon getippt hat oder nicht. Wenn er die Spiele des Tages schon getippt hat, dann sollte keine Push Notification verschickt werden. Wenn er die Spiele des Tages noch nicht getippt hat, dann sollte eine Push Notification verschickt werden, dass er noch Tipps abgeben kann.
- [x] In der Detailansicht zu den Tipps eines einzelnen Spielers, also in der Liste der Spiele sollte man auch auf ein Spiel klicken können, um die Detailansicht zu diesem Spiel zu sehen. Wichtig ist die Navigation und das Routing, beim zurück klicken sollte man auch wieder auf die Detailansicht des Spielers zurückkommen.
- [x] In der Detailansicht zu den einzelnen Spielen sollte vor dem Anpfiff, also in der Phase, in der noch Tipps abgegeben werden können die letzten 5 Ergebnisse der beiden Teams angezeigt werden, inklusive grünem W Indikator für Siege und grau D für Unentschieden und rot L für Niederlagen. Arbeite mit zwei Spalten, eine für jedes Team und dabei dann immer das Ergebnis, den Gegner und das Datum (kompakt untereinander). Wenn weniger als 5 Spiele in dem Turnier stattgefunden haben, dann sollten auch nur die Spiele des Turniers mit diesen Teams angezeigt werden.
- [x] Ich brauche auch noch in der Spieler Detail Ansicht eine Möglichkeit die Spiele nach Datum zu filtern, also wie im Spiele Tab mit dem Switch zwischen "Spiele Liste" und "Spiele Swipe nach Tagen". Also in der Detail Ansicht eines Spielers sollte es auch die Möglichkeit geben, die Spiele nach Datum zu filtern. Die Auswahl sollte gespeichert werden und auch immer an das aktuelle Datum angepasst werden, aber Tage, an denen keine Spiele stattfinden, sollten übersprungen werden.

## Bugs

- [x] Im Turnierbaum sind zwar die Spiele zwar korrekt angezeigt mit Mannschaften, aber der Aufbau des Turnierbaums ist nicht korrekt. Es sind zum Beispiel die Spiele Südafrika vs. Kanada und Brasilien vs. Japan direkt die ersten Spiele oben links, aber die Sieger der Spieler spielen gar nicht gegeneinander. Verstehst du, was ich meine? Es ist nicht der korrekte Turnierbaum, wie von der FIFA vorgegeben. Außerdem sollten die Kacheln für die Spiele so verbunden werden, dass besser klar wird, welche Teams in der kommenden Runde dann auch gegeneinander spielen. Also die Kacheln sollten so verbunden werden, dass klar wird, dass die Sieger der Spiele in der nächsten Runde gegeneinander spielen.

## Fixed Bugs

- [x] Im Spiele Tab wird die Auswahl zwischen "Spiele Liste" und "Spiele Swipe nach Tagen" nicht gespeichert. Außerdem wird beim Klick auf den Switch zwar der korrekte Tag oben angezeigt, aber die Spiele sind noch die vom 11.06., obwohl zum Beispiel schon der 27.06. ist.

## Later

- [ ] Add social feed, reactions, and comments.
- [ ] Add bonus questions for champion, group winners, and top scorer.
- [ ] Add push notifications for upcoming lock deadlines.
- [ ] Add tournament recap after the final.

## In Progress

- [ ]

## Done

- [x] Wir müssen das Tippen der K.O.-Spiele um Verlängerung (VL) und Elfmeterschießen erweitern. (siehe Features-Liste oben)
- [x] Make documentation-only pull requests satisfy the required CI check without running Flutter setup, analysis, or tests.
- [x] Add league tip-only points, Android push reminders, player detail date filtering/navigation, recent form, saved match date mode, and FIFA bracket connections.
- [x] Fix knockout risk scoring after round-of-32 wins, repair inconsistent penalty-shootout results, and resolve bracket winners into the correct next-round slots.
