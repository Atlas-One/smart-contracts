/** @format */
function getMonday(d) {
  d = new Date(d);
  var day = d.getDay(),
    diff = d.getDate() - day + (day == 0 ? -6 : 1); // adjust when day is sunday
  return new Date(d.setDate(diff));
}

module.exports = {
  networks: {
    mainnet: "https://mainnet.smartpy.io",
    // ithacanet: "https://ithacanet.smartpy.io",
    // hangzhounet: "https://hangzhounet.smartpy.io",
    jakartanet: "https://jakartanet.smartpy.io",
    mondaynet: `https://rpc.mondaynet-${getMonday(new Date())
      .toLocaleDateString("en-GB")
      .split("/")
      .reverse()
      .join("-")}.teztnets.xyz`,
  },
};
