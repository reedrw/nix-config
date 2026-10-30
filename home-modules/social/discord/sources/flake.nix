{
  inputs = {
    nixcord.url = "github:4evy/nixcord";
    vencord = {
      url = "github:Vendicated/Vencord";
      flake = false;
    };
  };

  outputs = _: { };
}
