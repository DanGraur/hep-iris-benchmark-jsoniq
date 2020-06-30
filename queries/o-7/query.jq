import module namespace hep = "../common/hep.jq";
declare variable $dataPath as anyURI external := anyURI("../../data/Run2012B_SingleMu.root");

let $histogram := hep:histogramConsts(15, 200, 100)

let $filtered := (
  for $i in hep:RestructureDataParquet($dataPath)

  let $filteredJets := (
    for $jet in $i.jets[]
    where $jet.pt > 30

    let $filteredElectrons := (
      for $electron in $i.electrons[]
      where $electron.pt > 10 and hep:DeltaR($jet, $electron) < 40
      return $electron
    )
    where empty($filteredElectrons)

    let $filteredMuons := (
      for $muon in $i.muons[]
      where $muon.pt > 10 and hep:DeltaR($jet, $muon) < 40
      return $muon
    )
    where empty($filteredMuons)

    return $jet
  )
  where exists($filteredJets)

  return sum($filteredJets.pt)
)

return hep:buildHistogram($filtered, $histogram)
