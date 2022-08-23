# AirPolicing


## TODO

### Show of force (SOF)
This one can be tricky to initiate from cockpit. For sea groups it should be somewhat fine, as those can be spotted by pilot as IRL, and we can use same mechanic as with aerial grops (scan area and build menus). 

For ground units it's trickier as a scan would reveal the presense of groups the pilot might not be able to visually aqcuire, ruining realism. We can look at other ways to detect and designate ground groups, including using the A-G radar. Check this link out: https://forum.dcs.world/topic/66528-enemy-radar-detection-triggering/page/2/

Another possibility could be using the DCS "Cockpit Visual Recon Mode". Need to look into whether this can be used from Lua in any way

### Randomized intruder reactions
Suggested syntax, using '@' qualifier: atk1@40%>divt = attack 1 (if intruder feels superior to interceptor) at 40% chance; otherwise intruder diverts

### Ability to specify what triggers intruder behavior. ATM it is always triggered by interceptore signalling 'follow me' but at times it would make sense to have intruder react already as the interceptor is closing or is getting established in the intercept position
