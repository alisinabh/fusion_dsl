# Test configurations
use Mix.Config

config :fusion_dsl,
  packages: [
    {FusionDslTest.SampleImpl, [as: "SampleImpl"]},
    {FusionDslTest.SampleImpl2, [as: "ChangeNameImpl"]},
    {String, [type: :native]},
    {Enum, [type: :native]}
  ]
