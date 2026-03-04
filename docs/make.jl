# Script to build the MultiDocumenter docs
#
#   julia --project docs/make.jl [--temp] [deploy]
#
# When `deploy` is passed as an argument, it goes into deployment mode
# and attempts to push the generated site to gh-pages. You can also pass
# `--temp`, in which case the source repositories are cloned into a temporary
# directory (as opposed to `docs/clones`).
using Documenter: Documenter
using ITensorDocs: ITensorDocs
using ITensorFormatter: ITensorFormatter
using MultiDocumenter: MultiDocumenter

clonedir = ("--temp" in ARGS) ? mktempdir() : joinpath(@__DIR__, "clones")
outpath = mktempdir()
@info """
Cloning packages into: $(clonedir)
Building aggregate site into: $(outpath)
"""

@info "Building Documenter site for ITensorDocs"
ITensorFormatter.make_index!(pkgdir(ITensorDocs))
Documenter.makedocs(;
    sitename = "ITensor ecosystem docs",
    modules = [ITensorDocs],
    warnonly = true,
    format = Documenter.HTML(; assets = ["assets/favicon.ico", "assets/extras.css"]),
    pages = [
        "Introduction" => "index.md",
        "Frequently Asked Questions" => [
            "Programming Language (Julia, C++, ...) FAQs" => "faq/JuliaAndCpp.md",
            "High-Performance Computing FAQs" => "faq/HPC.md",
        ],
    ]
)

function itensor_multidocref(pkgname::String; clonedir::String = clonedir)
    return MultiDocumenter.MultiDocRef(;
        upstream = joinpath(clonedir, pkgname),
        path = pkgname,
        name = pkgname,
        giturl = "https://github.com/ITensor/$(pkgname).jl.git"
    )
end

@info "Building aggregate ITensorDocs site"
docs = [
    # We also add ITensorDocs's own generated pages
    MultiDocumenter.MultiDocRef(;
        upstream = joinpath(@__DIR__, "build"),
        path = "Overview",
        name = "Home",
        fix_canonical_url = false
    ),
    itensor_multidocref("ITensors"),
    itensor_multidocref("ITensorMPS"),
]

MultiDocumenter.make(
    outpath,
    docs;
    search_engine = MultiDocumenter.SearchConfig(;
        index_versions = ["stable"], engine = MultiDocumenter.FlexSearch
    ),
    rootpath = "/ITensorDocs/",
    canonical_domain = "https://itensor.github.io/",
    sitemap = true,
    assets_dir = "docs/src/assets",
    brand_image = MultiDocumenter.BrandImage(
        "https://itensor.org", joinpath("assets", "logo-dark.png")
    )
)

if "deploy" in ARGS
    @warn "Deploying to GitHub" ARGS
    gitroot = normpath(joinpath(@__DIR__, ".."))
    run(`git pull`)
    outbranch = "gh-pages"
    has_outbranch = true
    if !success(`git checkout $outbranch`)
        has_outbranch = false
        if !success(`git switch --orphan $outbranch`)
            @error "Cannot create new orphaned branch $outbranch."
            exit(1)
        end
    end
    for file in readdir(gitroot; join = true)
        endswith(file, ".git") && continue
        rm(file; force = true, recursive = true)
    end
    for file in readdir(outpath)
        cp(joinpath(outpath, file), joinpath(gitroot, file))
    end
    # Specify a custom domain.
    write(joinpath(gitroot, "CNAME"), "docs.itensor.org")
    run(`git add .`)
    if success(`git commit -m 'Aggregate documentation'`)
        @info "Pushing updated documentation."
        if has_outbranch
            run(`git push`)
        else
            run(`git push -u origin $outbranch`)
        end
        run(`git checkout main`)
    else
        @info "No changes to aggregated documentation."
    end
else
    @info "Skipping deployment, 'deploy' not passed. Generated files in docs/out." ARGS
    cp(outpath, joinpath(@__DIR__, "out"); force = true)
end
