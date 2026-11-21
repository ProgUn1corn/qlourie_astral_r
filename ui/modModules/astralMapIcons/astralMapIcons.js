window.angular.module("astralMapIcons", []).run(function () {
  // The array index matches the ECU's mapId.
  const files = ["road", "stage1", "stage2", "stage3", "stage4"];
  const symbols = files.map((name, mapId) => `
    <symbol id="astral_map_${mapId}" viewBox="0 0 36 36">
      <image href="/ui/modModules/astralMapIcons/${name}.svg" width="36" height="36" />
    </symbol>`).join("");

  document.body.insertAdjacentHTML("beforeend", `
    <svg xmlns="http://www.w3.org/2000/svg" width="0" height="0"
         style="position:absolute;pointer-events:none" aria-hidden="true">
      <defs>${symbols}</defs>
    </svg>`);
});
