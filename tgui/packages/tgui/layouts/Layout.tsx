/* eslint-disable func-style */
/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { classes } from 'common/react';
import { useEffect, useRef } from 'react';

import {
  BoxProps,
  computeBoxClassName,
  computeBoxProps,
} from '../components/Box';
import { addScrollableNode, removeScrollableNode } from '../events';

type Props = Partial<{
  theme: string;
  /**
   * Optional accent layer (see tgui/styles/themes/admin.scss) for themes that support
   * escalation/faction signal without switching the whole theme file — e.g.
   * themeAccent="critical" on the admin theme. No-op for themes that don't define
   * data-admin-accent selectors.
   */
  themeAccent: string;
}> &
  BoxProps;

export function Layout(props: Props) {
  const {
    className,
    theme = 'weyland_yutani',
    themeAccent,
    children,
    ...rest
  } = props;
  document.documentElement.className = `theme-${theme}`;

  return (
    <div className={'theme-' + theme} data-admin-accent={themeAccent}>
      <div
        className={classes(['Layout', className, computeBoxClassName(rest)])}
        {...computeBoxProps(rest)}
      >
        {children}
      </div>
    </div>
  );
}

type ContentProps = Partial<{
  scrollable: boolean;
}> &
  BoxProps;

function LayoutContent(props: ContentProps) {
  const { className, scrollable, children, ...rest } = props;
  const node = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const self = node.current;

    if (self && scrollable) {
      addScrollableNode(self);
    }
    return () => {
      if (self && scrollable) {
        removeScrollableNode(self);
      }
    };
  }, []);

  return (
    <div
      className={classes([
        'Layout__content',
        scrollable && 'Layout__content--scrollable',
        className,
        computeBoxClassName(rest),
      ])}
      ref={node}
      {...computeBoxProps(rest)}
    >
      {children}
    </div>
  );
}

Layout.Content = LayoutContent;
