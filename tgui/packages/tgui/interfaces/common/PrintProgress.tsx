import { clamp } from 'common/math';

import { ProgressBar } from '../../components';

type Props = {
  /** world.time this print job started, in deciseconds. */
  readonly startedAt: number;
  /** world.time this print job will finish, in deciseconds. */
  readonly endsAt: number;
  /** Current world.time, as sent fresh in ui_data() each update. */
  readonly worldTime: number;
  readonly children?: React.ReactNode;
};

/**
 * A live print/copy-job progress bar, generalized from the worldtime/printtime
 * math BioSyntheticPrinter.tsx already used for its own single-consumer case.
 * Shared by Autolathe (currently_making) and Photocopier (in-flight copy batch)
 * so both draw from the same, once-verified percentage calculation.
 */
export const PrintProgress = (props: Props) => {
  const { startedAt, endsAt, worldTime, children } = props;
  const totalDuration = Math.max(1, endsAt - startedAt);
  const percent = clamp(1 - (endsAt - worldTime) / totalDuration, 0, 1);

  return <ProgressBar value={percent}>{children}</ProgressBar>;
};
