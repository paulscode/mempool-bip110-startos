import { VersionGraph } from '@start9labs/start-sdk'
import { current } from './current'
import { v3_2_1_3 } from './v3_2_1_3'

export const versionGraph = VersionGraph.of({
  current,
  other: [v3_2_1_3],
})
