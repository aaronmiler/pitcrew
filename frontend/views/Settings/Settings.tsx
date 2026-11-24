import { useQuery } from "@tanstack/react-query"

import { apiSettings } from "../../lib/routes"
import type { Settings as ISettings } from "../../types"
import BranchNames from "./BranchNames"
import Credentials from "./Credentials"
import KeepCurrent from "./KeepCurrent"
import PrTitles from "./PrTitles"
import Resolvers from "./Resolvers"
import TimeSaved from "./TimeSaved"

const Settings = () => {
  const { data: settings } = useQuery({ queryKey: ["settings"], queryFn: () => apiSettings.show<ISettings>() })

  return (
    <section className="space-y-6">
      <h1 className="heading">Settings</h1>
      <PrTitles settings={settings} />
      <BranchNames settings={settings} />
      <KeepCurrent settings={settings} />
      <TimeSaved settings={settings} />
      <Resolvers />
      <Credentials />
    </section>
  )
}

export default Settings
