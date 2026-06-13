defmodule Certitudo.Forma do
  @moduledoc """
  Structural forms for block-first coverage diff.

  These modules name the first-orbit objects only. They do not interpret or
  compare coverage data.
  """

  defmodule Conspectus do
    @moduledoc """
    A captured coverage run — comprehensive view of coverage at a moment in time.
    """

    @enforce_keys [:schema_version, :run, :modules]
    defstruct [
      :schema_version,
      :run,
      :filter,
      :totals,
      :modules
    ]

    @type t :: %__MODULE__{
            schema_version: pos_integer(),
            run: map(),
            filter: map() | nil,
            totals: map() | nil,
            modules: %{optional(binary()) => Certitudo.Forma.Module.t()}
          }
  end

  defmodule Module do
    @moduledoc """
    A module entry inside a coverage conspectus.
    """

    @enforce_keys [:name, :lines]
    defstruct [
      :name,
      :source,
      :source_size,
      :source_sha256,
      :coverage_percent,
      :covered_lines,
      :executable_lines,
      :lines
    ]

    @type t :: %__MODULE__{
            name: binary(),
            source: binary() | nil,
            source_size: non_neg_integer() | nil,
            source_sha256: binary() | nil,
            coverage_percent: float() | nil,
            covered_lines: non_neg_integer() | nil,
            executable_lines: non_neg_integer() | nil,
            lines: [Certitudo.Forma.Line.t()]
          }
  end

  defmodule Line do
    @moduledoc """
    An executable line fact.
    """

    @enforce_keys [:number, :calls, :covered]
    defstruct [
      :number,
      :calls,
      :covered,
      :text
    ]

    @type t :: %__MODULE__{
            number: pos_integer(),
            calls: non_neg_integer(),
            covered: boolean(),
            text: binary() | nil
          }
  end

  defmodule Ambitus do
    @moduledoc """
    The coordinate extent of a tractus — first, last, and all line numbers.
    """

    @enforce_keys [:first, :last, :numbers]
    defstruct [
      :first,
      :last,
      :numbers
    ]

    @type t :: %__MODULE__{
            first: pos_integer(),
            last: pos_integer(),
            numbers: [pos_integer()]
          }
  end

  defmodule Tractus do
    @moduledoc """
    A contiguous stretch of executable lines that moves as a unit during comparison.
    """

    @enforce_keys [:range, :lines]
    defstruct [
      :range,
      :lines,
      :text_fingerprint,
      :coverage_fingerprint
    ]

    @type t :: %__MODULE__{
            range: Certitudo.Forma.Ambitus.t(),
            lines: [Certitudo.Forma.Line.t()],
            text_fingerprint: binary() | nil,
            coverage_fingerprint: binary() | nil
          }
  end

  defmodule Collatio do
    @moduledoc """
    A relation between left and right tractus after textual comparison.
    """

    @enforce_keys [:kind]
    defstruct [
      :kind,
      :left,
      :right,
      :ambiguous
    ]

    @type kind ::
            :same_text_same_coverage
            | :same_text_changed_coverage
            | :left_only
            | :right_only
            | :ambiguous

    @type t :: %__MODULE__{
            kind: kind(),
            left: Certitudo.Forma.Tractus.t() | nil,
            right: Certitudo.Forma.Tractus.t() | nil,
            ambiguous: [Certitudo.Forma.Tractus.t()] | nil
          }
  end

  defmodule Differentia do
    @moduledoc """
    The result of distinguishing a pair of tractus — what right is from left
    in text and coverage. Named after the Aristotelian differentia specifica.
    """

    @enforce_keys [:status]
    defstruct [
      :status,
      :left,
      :right,
      :delta,
      :residue
    ]

    @type status ::
            :unchanged
            | :moved_unchanged
            | :moved_coverage_changed
            | :new_covered
            | :new_uncovered
            | :removed_covered
            | :removed_uncovered
            | :existing_coverage_gained
            | :existing_coverage_lost
            | :existing_coverage_mixed
            | :ambiguous_moved

    @type t :: %__MODULE__{
            status: status(),
            left: Certitudo.Forma.Tractus.t() | nil,
            right: Certitudo.Forma.Tractus.t() | nil,
            delta: map() | nil,
            residue: Certitudo.Forma.Residuatum.t() | nil
          }
  end

  defmodule LineaDifferentia do
    @moduledoc """
    A line-level differentia entry inside a tractus differentia.
    """

    @enforce_keys [:status]
    defstruct [
      :status,
      :left,
      :right
    ]

    @type status ::
            :moved_unchanged
            | :new_covered
            | :new_uncovered
            | :removed_covered
            | :removed_uncovered
            | :existing_coverage_gained
            | :existing_coverage_lost

    @type t :: %__MODULE__{
            status: status(),
            left: Certitudo.Forma.Line.t() | nil,
            right: Certitudo.Forma.Line.t() | nil
          }
  end

  defmodule Residuatum do
    @moduledoc """
    Details not fully explained by tractus-level judgment.
    """

    @enforce_keys [:reason]
    defstruct [
      :reason,
      :entries,
      :blocks,
      :details
    ]

    @type reason ::
            :coverage_changed
            | :new_block
            | :removed_block
            | :ambiguous_block

    @type t :: %__MODULE__{
            reason: reason(),
            entries: [Certitudo.Forma.LineaDifferentia.t()] | nil,
            blocks: [Certitudo.Forma.Tractus.t()] | nil,
            details: map() | nil
          }
  end
end
