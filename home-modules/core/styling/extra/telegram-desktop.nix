{ pkgs, lib, config, ... }:

{
  options.stylix.targets.telegram-desktop.enable = lib.mkEnableOption "Enable Telegram theme";
  config = lib.mkIf config.stylix.targets.telegram-desktop.enable {
    home.file.".config/colors.tdesktop-theme".text = with config.lib.stylix.colors; ''
      windowBg: #${base01};
      windowFg: #${base06};
      windowBgOver: #${base01};
      windowBgRipple: #${base08};
      windowFgOver: windowFg;
      windowSubTextFg: #${base05};
      windowSubTextFgOver: #${base0D};
      windowBoldFg: #${base06};
      windowBoldFgOver: #${base0D};
      windowBgActive: #${base0D};
      windowFgActive: #${base00};
      windowActiveTextFg: #${base05};
      windowShadowFg: #0000007f;
      windowShadowFgFallback: #00000000;
      shadowFg: #00000000;
      slideFadeOutBg: #00000000;
      slideFadeOutShadowFg: #00000000;
      imageBg: #000000;
      imageBgTransparent: #000000;
      activeButtonBg: #${base03};
      activeButtonBgOver: #${base03};
      activeButtonBgRipple: #${base02};
      activeButtonFg: #${base05};
      activeButtonFgOver: activeButtonFg;
      activeButtonSecondaryFg: #${base05};
      activeButtonSecondaryFgOver: #${base05};
      activeLineFg: #${base05};
      activeLineFgError: #${base08};
      lightButtonBg: #${base01};
      lightButtonBgOver: #${base01};
      lightButtonBgRipple: #${base02};
      lightButtonFg: activeButtonFg;
      lightButtonFgOver: lightButtonFg;
      attentionButtonFg: #${base08};
      attentionButtonFgOver: #${base08};
      attentionButtonBgOver: #${base08}1d;
      attentionButtonBgRipple: #${base08};
      outlineButtonBg: #${base01};
      outlineButtonBgOver: lightButtonBgOver;
      outlineButtonOutlineFg: windowBgActive;
      outlineButtonBgRipple: lightButtonBgRipple;
      menuBg: #${base01};
      menuBgOver: windowBgOver;
      menuBgRipple: windowBgRipple;
      menuIconFg: #${base05};
      menuIconFgOver: #${base03};
      menuSubmenuArrowFg: #${base03};
      menuFgDisabled: #${base03};
      menuSeparatorFg: #${base05};
      scrollBarBg: #${base04};
      scrollBarBgOver: #${base04};
      scrollBg: #${base01};
      scrollBgOver: #${base01};
      smallCloseIconFg: #${base05};
      smallCloseIconFgOver: #${base03};
      radialFg: #${base05};
      radialBg: #${base00};
      placeholderFg: windowSubTextFg;
      placeholderFgActive: #${base03};
      inputBorderFg: #${base03};
      filterInputBorderFg: #${base02};
      filterInputInactiveBg: #${base02};
      checkboxFg: #${base05};
      sliderBgInactive: #${base01};
      sliderBgActive: #${base05};
      tooltipBg: #${base07};
      tooltipFg: #${base0D};
      tooltipBorderFg: #${base05};
      titleShadow: #00000000;
      titleBg: #${base01};
      titleBgActive: #${base01};
      titleButtonBg: titleBg;
      titleButtonFg: #${base03};
      titleButtonBgOver: #${base01};
      titleButtonFgOver: #${base05};
      titleButtonBgActive: titleButtonBg;
      titleButtonFgActive: titleButtonFg;
      titleButtonBgActiveOver: titleButtonBgOver;
      titleButtonFgActiveOver: #${base05};
      titleButtonCloseBg: titleButtonBg;
      titleButtonCloseFg: titleButtonFg;
      titleButtonCloseBgOver: #${base08};
      titleButtonCloseFgOver: #${base05};
      titleButtonCloseBgActive: titleButtonCloseBg;
      titleButtonCloseFgActive: windowBoldFg;
      titleButtonCloseBgActiveOver: #${base08};
      titleButtonCloseFgActiveOver: titleButtonCloseFgOver;
      titleFgActive: windowBoldFg;
      titleFg: windowSubTextFg;
      trayCounterBg: #${base01};
      trayCounterBgMute: #${base04};
      trayCounterFg: #${base05};
      trayCounterBgMacInvert: #${base05};
      trayCounterFgMacInvert: #${base00};
      layerBg: #0000007f;
      cancelIconFg: menuIconFg;
      cancelIconFgOver: menuIconFgOver;
      boxBg: #${base01};
      boxTextFg: windowFg;
      boxTextFgGood: #${base0B};
      boxTextFgError: #${base08};
      boxTitleFg: #${base05};
      boxSearchBg: #${base02};
      boxTitleAdditionalFg: #${base03};
      boxTitleCloseFg: cancelIconFg;
      boxTitleCloseFgOver: cancelIconFgOver;
      membersAboutLimitFg: windowSubTextFgOver;
      contactsBg: #${base01};
      contactsBgOver: windowBgOver;
      contactsNameFg: boxTextFg;
      contactsStatusFg: windowSubTextFg;
      contactsStatusFgOver: windowSubTextFgOver;
      contactsStatusFgOnline: #${base05};
      photoCropFadeBg: #${base02}7f;
      photoCropPointFg: #${base03}7f;
      introBg: #${base01};
      introTitleFg: #${base05};
      introDescriptionFg: windowSubTextFg;
      introErrorFg: #${base04};
      introCoverTopBg: #${base01};
      introCoverBottomBg: #${base01};
      introCoverIconsFg: #${base01};
      introCoverPlaneTrace: #${base04};
      introCoverPlaneInner: #${base03};
      introCoverPlaneOuter: #${base04};
      introCoverPlaneTop: #${base03};
      dialogsMenuIconFg: menuIconFg;
      dialogsMenuIconFgOver: menuIconFgOver;
      dialogsBg: #${base01};
      dialogsNameFg: #${base05};
      dialogsChatIconFg: dialogsNameFg;
      dialogsDateFg: #${base05};
      dialogsTextFg: #${base04};
      dialogsTextFgService: windowActiveTextFg;
      dialogsDraftFg: #${base0A};
      dialogsVerifiedIconBg: #${base05};
      dialogsVerifiedIconFg: #${base01};
      dialogsSendingIconFg: #${base05};
      dialogsSentIconFg: #${base05};
      dialogsUnreadBg: #${base05};
      dialogsUnreadBgMuted: #${base04};
      dialogsUnreadFg: #${base01};
      dialogsBgOver: #${base01};
      dialogsNameFgOver: #${base06};
      dialogsChatIconFgOver: #${base06};
      dialogsDateFgOver: #${base06};
      dialogsTextFgOver: windowSubTextFgOver;
      dialogsTextFgServiceOver: dialogsTextFgService;
      dialogsDraftFgOver: dialogsDraftFg;
      dialogsVerifiedIconBgOver: dialogsVerifiedIconBg;
      dialogsVerifiedIconFgOver: dialogsVerifiedIconFg;
      dialogsSendingIconFgOver: dialogsSendingIconFg;
      dialogsSentIconFgOver: dialogsSentIconFg;
      dialogsUnreadBgOver: dialogsUnreadBg;
      dialogsUnreadBgMutedOver: dialogsUnreadBgMuted;
      dialogsUnreadFgOver: dialogsUnreadFg;
      dialogsBgActive: #${base01};
      dialogsNameFgActive: #${base05};
      dialogsChatIconFgActive: #${base05};
      dialogsDateFgActive: #${base05};
      dialogsTextFgActive: #${base04};
      dialogsTextFgServiceActive: #${base05};
      dialogsDraftFgActive: windowSubTextFg;
      dialogsVerifiedIconBgActive: #${base05};
      dialogsVerifiedIconFgActive: dialogsVerifiedIconFg;
      dialogsSendingIconFgActive: dialogsSendingIconFg;
      dialogsSentIconFgActive: #${base05};
      dialogsUnreadBgActive: #${base05};
      dialogsUnreadBgMutedActive: dialogsUnreadBgMuted;
      dialogsUnreadFgActive: dialogsUnreadFg;
      dialogsForwardBg: dialogsBgActive;
      dialogsForwardFg: dialogsNameFgActive;
      searchedBarBg: #${base02};
      searchedBarFg: #${base01};
      topBarBg: #${base01};
      emojiPanBg: #${base01};
      emojiPanCategories: #${base01};
      emojiPanHeaderFg: #${base05};
      emojiPanHeaderBg: #${base03};
      stickerPanDeleteBg: #${base05}cc;
      stickerPanDeleteFg: #${base05};
      stickerPreviewBg: #${base03}b0;
      historyTextInFg: windowFg;
      historyTextInFgSelected: #${base00};
      historyTextOutFg: windowFg;
      historyCaptionInFg: historyTextInFg;
      historyCaptionOutFg: historyTextOutFg;
      historyFileNameInFg: historyTextInFg;
      historyFileNameOutFg: historyTextOutFg;
      historyOutIconFg: dialogsSentIconFg;
      historyOutIconFgSelected: #${base00};
      historyIconFgInverted: #${base05};
      historySendingOutIconFg: #${base04};
      historySendingInIconFg: #${base04};
      historySendingInvertedIconFg: #${base05};
      historyUnreadBarBg: #${base01};
      historyUnreadBarBorder: shadowFg;
      historyUnreadBarFg: #${base05};
      historyForwardChooseBg: #${base03}eb;
      historyForwardChooseFg: #${base05};
      historyPeer1NameFg: #${base08};
      historyPeer1UserpicBg: #${base08};
      historyPeer2NameFg: #${base0B};
      historyPeer2UserpicBg: #${base0B};
      historyPeer3NameFg: #${base0A};
      historyPeer3UserpicBg: #${base0A};
      historyPeer4NameFg: #${base0C};
      historyPeer4UserpicBg: #${base0C};
      historyPeer5NameFg: #${base09};
      historyPeer5UserpicBg: #${base09};
      historyPeer6NameFg: #${base0E};
      historyPeer6UserpicBg: #${base0E};
      historyPeer7NameFg: #${base0D};
      historyPeer7UserpicBg: #${base0D};
      historyPeer8NameFg: #${base0F};
      historyPeer8UserpicBg: #${base0F};
      historyPeerUserpicFg: #${base01};
      historyScrollBarBg: #${base04};
      historyScrollBarBgOver: #${base04};
      historyScrollBg: #${base01};
      historyScrollBgOver: #${base01};
      msgInBg: #${base01};
      msgInBgSelected: #${base0D};
      msgOutBg: #${base01};
      msgOutBgSelected: #${base0D}7f;
      msgSelectOverlay: #${base0D}7f;
      msgStickerOverlay: #${base0D}7f;
      msgInServiceFg: #${base05};
      msgInServiceFgSelected: #${base05};
      msgOutServiceFg: #${base0D};
      msgOutServiceFgSelected: activeLineFg;
      msgInShadow: #00000000;
      msgInShadowSelected: #00000000;
      msgOutShadow: #00000000;
      msgOutShadowSelected: #00000000;
      msgInDateFg: #${base04};
      msgInDateFgSelected: #${base00};
      msgOutDateFg: #${base05};
      msgOutDateFgSelected: #${base00};
      msgServiceFg: #${base05};
      msgServiceBg: #${base01};
      msgServiceBgSelected: #${base02};
      msgInReplyBarColor: #${base05};
      msgInReplyBarSelColor: #${base05};
      msgOutReplyBarColor: #${base05};
      msgOutReplyBarSelColor: #${base05};
      msgImgReplyBarColor: #${base05};
      msgInMonoFg: #${base05};
      msgOutMonoFg: #${base04};
      msgDateImgFg: #${base05};
      msgDateImgBg: #${base01};
      msgDateImgBgOver: #${base01};
      msgDateImgBgSelected: #${base00};
      msgFileThumbLinkInFg: lightButtonFg;
      msgFileThumbLinkInFgSelected: lightButtonFgOver;
      msgFileThumbLinkOutFg: windowActiveTextFg;
      msgFileThumbLinkOutFgSelected: windowActiveTextFg;
      msgFileInBg: #${base0D};
      msgFileInBgOver: windowSubTextFgOver;
      msgFileInBgSelected: windowBoldFg;
      msgFileOutBg: windowBoldFg;
      msgFileOutBgOver: windowSubTextFgOver;
      msgFileOutBgSelected: windowBoldFg;
      msgFile1Bg: #${base01};
      msgFile1BgDark: #${base05};
      msgFile1BgOver: #${base04};
      msgFile1BgSelected: #${base04};
      msgFile2Bg: #${base01};
      msgFile2BgDark: #${base05};
      msgFile2BgOver: #${base04};
      msgFile2BgSelected: #${base04};
      msgFile3Bg: #${base01};
      msgFile3BgDark: #${base05};
      msgFile3BgOver: #${base04};
      msgFile3BgSelected: #${base04};
      msgFile4Bg: #${base01};
      msgFile4BgDark: #${base05};
      msgFile4BgOver: #${base04};
      msgFile4BgSelected: #${base04};
      historyFileInIconFg: #${base01};
      historyFileInIconFgSelected: #${base0D};
      historyFileInRadialFg: historyFileInIconFg;
      historyFileInRadialFgSelected: historyFileInIconFgSelected;
      historyFileOutIconFg: msgOutBg;
      historyFileOutIconFgSelected: #${base0D};
      historyFileOutRadialFg: historyFileOutIconFg;
      historyFileOutRadialFgSelected: historyFileOutIconFgSelected;
      historyFileThumbIconFg: msgInBg;
      historyFileThumbIconFgSelected: #${base0D};
      historyFileThumbRadialFg: historyFileThumbIconFg;
      historyFileThumbRadialFgSelected: historyFileThumbIconFgSelected;
      msgWaveformInActive: #${base0D};
      msgWaveformInActiveSelected: #${base05};
      msgWaveformInInactive: #${base03};
      msgWaveformInInactiveSelected: #${base02};
      msgWaveformOutActive: #${base05};
      msgWaveformOutActiveSelected: #${base02};
      msgWaveformOutInactive: #${base01};
      msgWaveformOutInactiveSelected: msgInBgSelected;
      msgBotKbOverBgAdd: msgServiceBg;
      msgBotKbIconFg: msgServiceFg;
      msgBotKbRippleBg: menuBgRipple;
      mediaInFg: msgInDateFg;
      mediaInFgSelected: msgInDateFgSelected;
      mediaOutFg: msgOutDateFg;
      mediaOutFgSelected: msgOutDateFgSelected;
      youtubePlayIconBg: #0000007f;
      youtubePlayIconFg: #${base05};
      videoPlayIconBg: #0000007f;
      videoPlayIconFg: #${base05};
      toastBg: #${base01};
      toastFg: #${base05};
      reportSpamBg: #${base01};
      reportSpamFg: #${base05};
      historyToDownBg: #00000000;
      historyToDownBgOver: #0000002a;
      historyToDownBgRipple: windowBgRipple;
      historyToDownFg: #${base05};
      historyToDownFgOver: #${base04};
      historyToDownShadow: #00000000;
      historyComposeAreaBg: #${base01};
      historyComposeAreaFg: historyTextInFg;
      historyComposeAreaFgService: #${base05};
      historyComposeIconFg: #${base05};
      historyComposeIconFgOver: #${base05};
      historySendIconFg: #${base05};
      historySendIconFgOver: #${base05};
      historyPinnedBg: #${base01};
      historyReplyBg: historyComposeAreaBg;
      historyReplyIconFg: historyTextInFg;
      historyReplyCancelFg: #${base05};
      historyReplyCancelFgOver: #${base05};
      historyComposeButtonBg: historyComposeAreaBg;
      historyComposeButtonBgOver: windowBgOver;
      historyComposeButtonBgRipple: windowBgRipple;
      overviewCheckBg: #${base03}71;
      overviewCheckFg: #${base04};
      overviewCheckFgActive: #${base01};
      overviewPhotoSelectOverlay: #bdbdbd4a;
      profileStatusFgOver: #${base04};
      profileVerifiedCheckBg: #${base05};
      profileVerifiedCheckFg: #${base01};
      profileAdminStartFg: #${base05};
      notificationsBoxMonitorFg: windowFg;
      notificationsBoxScreenBg: windowSubTextFg;
      notificationSampleUserpicFg: #${base01};
      notificationSampleCloseFg: #${base06};
      notificationSampleTextFg: #${base06};
      notificationSampleNameFg: #${base04};
      mainMenuBg: #${base01};
      mainMenuCoverBg: #${base01};
      mainMenuCoverFg: #${base05};
      mediaPlayerBg: #${base01};
      mediaPlayerActiveFg: #${base05};
      mediaPlayerInactiveFg: #${base03};
      mediaPlayerDisabledFg: #${base03};
      mediaviewFileBg: #000000;
      mediaviewFileNameFg: windowFg;
      mediaviewFileSizeFg: windowSubTextFg;
      mediaviewFileRedCornerFg: #${base08};
      mediaviewFileYellowCornerFg: #${base0A};
      mediaviewFileGreenCornerFg: #${base0B};
      mediaviewFileBlueCornerFg: #${base0D};
      mediaviewFileExtFg: activeButtonFg;
      mediaviewMenuBg: #${base01};
      mediaviewMenuBgOver: menuBgOver;
      mediaviewMenuBgRipple: menuBgRipple;
      mediaviewMenuFg: windowBoldFg;
      mediaviewBg: #000000;
      mediaviewVideoBg: imageBg;
      mediaviewControlBg: #${base07}7f;
      mediaviewControlFg: #${base05};
      mediaviewCaptionBg: #0000007f;
      mediaviewCaptionFg: #${base05};
      mediaviewTextLinkFg: #${base0D};
      mediaviewSaveMsgBg: toastBg;
      mediaviewSaveMsgFg: toastFg;
      mediaviewPlaybackActive: #${base05};
      mediaviewPlaybackInactive: #${base03};
      mediaviewPlaybackActiveOver: #${base05};
      mediaviewPlaybackInactiveOver: windowSubTextFgOver;
      mediaviewPlaybackProgressFg: #${base05};
      mediaviewPlaybackIconFg: mediaviewPlaybackActive;
      mediaviewPlaybackIconFgOver: mediaviewPlaybackActiveOver;
      mediaviewTransparentBg: #000000ff;
      mediaviewTransparentFg: #${base05};
      notificationBg: #${base01};

      emojiIconFg: #${base04};
      historyLinkOutFg: #${base08};
      historyLinkInFg: #${base08};
      sideBarBg: #${base00};
      sideBarBgActive: #${base01};
      sideBarTextFgActive: #${base0D};
      sideBarIconFgActive: #${base0D};
      sideBarBadgeBg: #${base0D};
      sideBarTextFg: #${base03};
      sideBarBadgeBgMuted: #${base03};
      sideBarBgRipple: #${base08};
      sideBarIconFg: #${base03};
      mainMenuCloudBg: #${base03};
      filterInputActiveBg: #${base0D};
      overviewCheckBorder: #${base08};
      sideBarBadgeFg: #${base00};
      dialogsOnlineBadgeFgActive: #${base08};
      walletTitleButtonCloseFgActiveOver: #${base08};
    '';
    home.activation = with config.lib.stylix.colors; {
      tg-theme = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        ${pkgs.imagemagick}/bin/magick -size 2960x2960 xc:#${base00} ~/.config/background.jpg
        cd ~/.config && ${pkgs.zip}/bin/zip telegram-base16.zip background.jpg colors.tdesktop-theme && rm -rf colors.tdesktop-theme background.jpg && mv telegram-base16.zip telegram-base16.tdesktop-theme
      '';
    };
  };
}