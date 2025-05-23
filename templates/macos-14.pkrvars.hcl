macos_version = "14"
boot_command = [
  # hello, hola, bonjour, etc.
  "<wait60s><spacebar>",

  # Language: most of the times we have a list of "English"[1], "English (UK)", etc. with
  # "English" language already selected. If we type "english", it'll cause us to switch
  # to the "English (UK)", which is not what we want. To solve this, we switch to some other
  # language first, e.g. "Italiano" and then switch back to "English". We'll then jump to the
  # first entry in a list of "english"-prefixed items, which will be "English".
  #
  # [1]: should be named "English (US)", but oh well 🤷
  "<wait60s>italiano<esc>english<enter>",

  # Select Your Country and Region
  "<wait30s>united states<leftShiftOn><tab><leftShiftOff><spacebar>",

  # Written and Spoken Languages
  "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

  # Accessibility
  "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

  # Data & Privacy
  "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

  # Migration Assistant
  "<wait10s><tab><tab><tab><spacebar>",

  # Sign In with Your Apple ID
  "<wait10s><leftShiftOn><tab><tab><leftShiftOff><spacebar>",

  # Are you sure you want to skip signing in with an Apple ID?
  "<wait10s><tab><spacebar>",

  # Terms and Conditions
  "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

  # I have read and agree to the macOS Software License Agreement
  "<wait10s><tab><spacebar>",

  # Create a Computer Account
  "<wait10s>admin<tab><tab>admin<tab>admin<tab><tab><tab><spacebar>",

  # Enable Location Services
  "<wait120s><leftShiftOn><tab><leftShiftOff><spacebar>",

  # Are you sure you don't want to use Location Services?
  "<wait10s><tab><spacebar>",

  # Select Your Time Zone
  "<wait10s><tab>UTC<enter><leftShiftOn><tab><leftShiftOff><spacebar>",

  # Analytics
  "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

  # Screen Time
  "<wait10s><tab><spacebar>",

  # Siri
  "<wait10s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",

  # Choose Your Look
  "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

  # Welcome to Mac
  "<wait10s><spacebar>",

  # Enable Keyboard navigation
  # This is so that we can navigate the System Settings app using the keyboard
  "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
  "<wait5s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",
  "<wait5s><leftAltOn>q<leftAltOff>",

  # Now that the installation is done, open "System Settings"
  "<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",

  # Navigate to "Sharing"
  "<wait10s><leftAltOn><leftShiftOn>/<leftShiftOff><leftAltOff>Sharing<down><enter>",

  # Navigate to "Screen Sharing" and enable it
  "<wait10s><tab><tab><tab><tab><tab><tab><tab><spacebar>",

  # Navigate to "Remote Login" and enable it
  "<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",

  # Quit System Settings
  "<wait10s><leftAltOn>q<leftAltOff>",
]
