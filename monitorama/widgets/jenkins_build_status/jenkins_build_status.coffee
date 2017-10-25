class Dashing.JenkinsBuildStatus extends Dashing.Widget

  lastPlayed: 0
  timeBetweenSounds: 300000

  onData: (data) ->
    if data.failed
      $(@node).find('div.build-failed').show()
      $(@node).find('div.build-succeeded').hide()
      $(@node).css("background-color", "red")

      if 'speechSynthesis' of window
        @playSoundForUser data.failedJobs[0].value if Date.now() - @lastPlayed > @timeBetweenSounds
    else
      $(@node).find('div.build-failed').hide()
      $(@node).find('div.build-succeeded').show()
      $(@node).css("background-color", "#12b0c5")

  playSoundForUser: (user) ->
    @lastPlayed = Date.now()
    texts = ["#{user} has broken the build.", "The build is broken by #{user}", "#{user} is great, but lacks some programming skills", "Oops, I did it again."]
    textNr = Math.floor((Math.random() * texts.length));
    @playSound texts[textNr]

  playSound: (text) ->
    msg = new SpeechSynthesisUtterance(text)
    msg.voice = speechSynthesis.getVoices()[0]
    speechSynthesis.speak msg