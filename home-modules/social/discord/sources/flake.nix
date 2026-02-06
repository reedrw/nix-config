{
  inputs = {
    nixcord.url = "github:kaylorben/nixcord";
    vencord = {
      url = "github:Vendicated/Vencord";
      flake = false;
    };
  };

  outputs = _: { };
}
