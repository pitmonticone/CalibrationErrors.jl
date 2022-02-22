# Retrieve name of example and output directory
if length(ARGS) != 1
    error("please specify the name of the output directory")
end
const RELOUTDIR = ARGS[1]
const EXAMPLEDIR = dirname(Base.active_project())
const EXAMPLE = basename(EXAMPLEDIR)
const OUTDIR = joinpath(@__DIR__, "src", RELOUTDIR, EXAMPLE)
mkpath(OUTDIR)

# Load non-example specific packages
using Literate: Literate # from stacked environment
using InteractiveUtils: InteractiveUtils
using Pkg: Pkg

# Save Manifest.toml
cp(
    Pkg.Types.manifestfile_path(EXAMPLEDIR; strict=true),
    joinpath(OUTDIR, "Manifest.toml");
    force=true,
)

# Strip build version from a tag (cf. JuliaDocs/Documenter.jl#1298, Literate.jl#162)
function version_tag_strip_build(tag)
    m = match(Base.VERSION_REGEX, tag)
    m === nothing && return tag
    s0 = startswith(tag, 'v') ? "v" : ""
    s1 = m[1] # major
    s2 = m[2] === nothing ? "" : ".$(m[2])" # minor
    s3 = m[3] === nothing ? "" : ".$(m[3])" # patch
    s4 = m[5] === nothing ? "" : m[5] # pre-release (starting with -)
    # m[7] is the build, which we want to discard
    return "$s0$s1$s2$s3$s4"
end

# Obtain name of deploy folder
function deployfolder(; devurl="dev")
    github_ref = get(ENV, "GITHUB_REF", "")
    if get(ENV, "GITHUB_EVENT_NAME", nothing) == "push"
        if (m = match(r"^refs\/tags\/(.*)$", github_ref)) !== nothing
            # new tags: correspond to a new version
            return version_tag_strip_build(String(m.captures[1]))
        end
    elseif (m = match(r"refs\/pull\/(\d+)\/merge", github_ref)) !== nothing
        # pull request: build preview
        "previews/PR$(m.captures[1])"
    end

    # fallback: development branch
    return devurl
end

# Add link to nbviewer below the first heading of level 1 and add footer
const RELEXAMPLEDIR = relpath(EXAMPLEDIR, joinpath(@__DIR__, ".."))
const DEPLOYFOLDER = deployfolder()
function preprocess(content)
    io = IOBuffer()

    # Print initial lines, up to and including the first heading of level 1
    lines = eachline(IOBuffer(content))
    for line in lines
        println(io, line)
        startswith(line, "# # ") && break
    end

    # Add header
    print(
        io,
        """
        #
        #md # [![](https://img.shields.io/badge/show-nbviewer-579ACA.svg)](@__NBVIEWER_ROOT_URL__/$RELOUTDIR/$EXAMPLE/notebook.ipynb)
        #md #
        # *You are seeing the
        #md # HTML output generated by [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) and
        #nb # notebook output generated by
        # [Literate.jl](https://github.com/fredrikekre/Literate.jl) from the
        # [Julia source file](@__REPO_ROOT_URL__/$RELEXAMPLEDIR/script.jl).
        # The corresponding
        #md # notebook can be viewed in [nbviewer](@__NBVIEWER_ROOT_URL__/$RELOUTDIR/$EXAMPLE/notebook.ipynb).*
        #nb # HTML output can be viewed [here](https://devmotion.github.io/CalibrationErrors.jl/$DEPLOYFOLDER/$RELOUTDIR/$EXAMPLE/).*
        #
        """,
    )

    # Print remaining lines
    for line in lines
        println(io, line)
    end

    # Add footer
    println(io, "# ### Package and system information")

    ## Add package status
    iopkg = IOBuffer()
    Pkg.status(; io=iopkg)
    seekstart(iopkg)
    println(io, "# #### Package version\n# ```julia")
    for l in eachline(iopkg)
        println(io, "# ", l)
    end
    println(io, "# ```")

    ## Add computer info
    ioversion = IOBuffer()
    InteractiveUtils.versioninfo(ioversion)
    seekstart(ioversion)
    println(io, "# #### Computer information\n# ```")
    for l in eachline(ioversion)
        println(io, "# ", l)
    end
    println(io, "# ```")

    ## Add link to Manifest file
    print(
        io,
        """
        # #### Manifest
        # To reproduce the project environment of this example you can [download the full Manifest.toml](./Manifest.toml).
        """,
    )

    return String(take!(io))
end

# Convert to markdown and notebook
const SCRIPTJL = joinpath(EXAMPLEDIR, "script.jl")
Literate.markdown(SCRIPTJL, OUTDIR; name="index", execute=true, preprocess=preprocess)
Literate.notebook(SCRIPTJL, OUTDIR; name="notebook", execute=true, preprocess=preprocess)
