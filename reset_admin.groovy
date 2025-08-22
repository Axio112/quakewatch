import jenkins.model.*
import hudson.security.*

def j = Jenkins.get()
def realm = j.getSecurityRealm()
if (!(realm instanceof HudsonPrivateSecurityRealm)) {
  realm = new HudsonPrivateSecurityRealm(false)   // keep local DB auth
  j.setSecurityRealm(realm)
}
def user = hudson.model.User.getById("admin", false)
if (user == null) {
  realm.createAccount("admin","admin123")
  j.save()
  println("Created admin with password: admin123")
} else {
  user.addProperty(HudsonPrivateSecurityRealm.Details.fromPlainPassword("admin123"))
  user.save()
  println("Reset admin password to: admin123")
}
